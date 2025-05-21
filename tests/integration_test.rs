use anyhow::Result;
use futures::SinkExt;
use futures::StreamExt;
use std::thread;
use std::time::Duration;
use tokio_tungstenite::connect_async;
use tracing::info;
mod common;

#[tokio::test]
async fn start_and_stop() -> Result<()> {
    // this will be the common pattern for acquiring a new relay:
    // start a fresh relay, on a port to-be-provided back to us:
    let relay = common::start_relay()?;
    // wait for the relay's webserver to start up and deliver a page:
    common::wait_for_healthy_relay(&relay).await?;
    let port = relay.port;
    // just make sure we can startup and shut down.
    // if we send a shutdown message before the server is listening,
    // we will get a SendError.  Keep sending until someone is
    // listening.
    loop {
        let shutdown_res = relay.shutdown_tx.send(());
        match shutdown_res {
            Ok(()) => {
                break;
            }
            Err(_) => {
                thread::sleep(Duration::from_millis(100));
            }
        }
    }
    // wait for relay to shutdown
    let thread_join = relay.handle.join();
    assert!(thread_join.is_ok());
    // assert that port is now available.
    assert!(common::port_is_available(port));
    Ok(())
}

#[tokio::test]
async fn relay_home_page() -> Result<()> {
    // get a relay and wait for startup...
    let relay = common::start_relay()?;
    common::wait_for_healthy_relay(&relay).await?;
    // tell relay to shutdown
    let _res = relay.shutdown_tx.send(());
    Ok(())
}

//#[tokio::test]
// Still inwork
async fn publish_test() -> Result<()> {
    // get a relay and wait for startup
    let relay = common::start_relay()?;
    common::wait_for_healthy_relay(&relay).await?;
    // open a non-secure websocket connection.
    let (mut ws, _res) = connect_async(format!("ws://localhost:{}", relay.port)).await?;
    // send a simple pre-made message
    let simple_event = r#"["EVENT", {"content": "hello world","created_at": 1691239763,
      "id":"f3ce6798d70e358213ebbeba4886bbdfacf1ecfd4f65ee5323ef5f404de32b86",
      "kind": 1,
      "pubkey": "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
      "sig": "30ca29e8581eeee75bf838171dec818af5e6de2b74f5337de940f5cc91186534c0b20d6cf7ad1043a2c51dbd60b979447720a471d346322103c83f6cb66e4e98",
      "tags": []}]"#;
    ws.send(simple_event.into()).await?;
    // get response from server, confirm it is an array with first element "OK"
    let event_confirm = ws.next().await;
    ws.close(None).await?;
    info!("event confirmed: {:?}", event_confirm);
    // open a new connection, and wait for some time to get the event.
    let (mut sub_ws, _res) = connect_async(format!("ws://localhost:{}", relay.port)).await?;
    let event_sub = r#"["REQ", "simple", {}]"#;
    sub_ws.send(event_sub.into()).await?;
    // read from subscription
    let _ws_next = sub_ws.next().await;
    let _res = relay.shutdown_tx.send(());
    Ok(())
}

#[tokio::test]
async fn protected_tag_rejected_by_default() -> Result<()> {
    let relay = common::start_relay()?;
    common::wait_for_healthy_relay(&relay).await?;
    let (mut ws, _res) = connect_async(format!("ws://localhost:{}", relay.port)).await?;
    // Event with a protected tag and valid id/sig
    let protected_event = r#"["EVENT", {"kind":1,"id":"1dc687a97c9824b28c89a955206cd6851e5ac6a767c5cc49591c018427afaa78","pubkey":"79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798","created_at":1747816564,"tags":[["-"]],"content":"hello from the nostr army knife","sig":"e498d336313fdc6f26179523da80c36052ded6c43341f8f0f21bc2f6ae3bfceb82118860e25a3bae0ddd28f8e3babe7dfd1fbdf3d27cd1a0209c798b3aba3fa2"}]"#;
    ws.send(protected_event.into()).await?;
    let response = ws.next().await;
    // Parse the response as a Nostr notice array and check for the error message
    let notice_msg = if let Some(Ok(msg)) = response {
        if let Ok(arr) = serde_json::from_str::<serde_json::Value>(&msg.to_string()) {
            if arr.is_array() && arr[0] == "NOTICE" {
                arr[1].as_str().unwrap_or("").to_string()
            } else {
                msg.to_string()
            }
        } else {
            msg.to_string()
        }
    } else {
        String::new()
    };
    println!("notice_msg: {}", notice_msg);
    assert!(notice_msg.contains("Relay does not accept events with protected tags"));
    ws.close(None).await?;
    let _ = relay.shutdown_tx.send(());
    Ok(())
}

#[tokio::test]
async fn protected_tag_requires_authentication() -> Result<()> {
    let mut settings = nostr_rs_relay::config::Settings::default();
    settings.protected_tags.enabled = true;
    settings.authorization.nip42_auth = true;
    let relay = common::start_relay_with_config(settings)?;
    common::wait_for_healthy_relay(&relay).await?;
    let (mut ws, _res) = connect_async(format!("ws://localhost:{}", relay.port)).await?;
    // Read and ignore the initial AUTH challenge
    let _auth_challenge = ws.next().await;
    // Event with a protected tag and valid id/sig
    let protected_event = r#"["EVENT", {"kind":1,"id":"1dc687a97c9824b28c89a955206cd6851e5ac6a767c5cc49591c018427afaa78","pubkey":"79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798","created_at":1747816564,"tags":[["-"]],"content":"hello from the nostr army knife","sig":"e498d336313fdc6f26179523da80c36052ded6c43341f8f0f21bc2f6ae3bfceb82118860e25a3bae0ddd28f8e3babe7dfd1fbdf3d27cd1a0209c798b3aba3fa2"}]"#;
    ws.send(protected_event.into()).await?;
    let response = ws.next().await;
    let notice_msg = if let Some(Ok(msg)) = response {
        if let Ok(arr) = serde_json::from_str::<serde_json::Value>(&msg.to_string()) {
            if arr.is_array() && arr[0] == "NOTICE" {
                arr[1].as_str().unwrap_or("").to_string()
            } else {
                msg.to_string()
            }
        } else {
            msg.to_string()
        }
    } else {
        String::new()
    };
    println!("notice_msg: {}", notice_msg);
    assert!(notice_msg.contains("Protected tag events require NIP-42 authentication"));
    ws.close(None).await?;
    let _ = relay.shutdown_tx.send(());
    Ok(())
}

