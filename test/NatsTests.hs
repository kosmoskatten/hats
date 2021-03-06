{-# LANGUAGE OverloadedStrings #-}
module NatsTests
    ( recSingleMessage
    , recSingleMessageAsync
    , recMessagesWithTmo
    , requestMessage
    , unsubscribeToTopic
    ) where

import Control.Concurrent.MVar
import Control.Monad
import Data.Maybe (fromJust)
import System.Timeout (timeout)
import Test.HUnit

import Gnatsd
import Network.Nats

-- Subscribe on a topic and receive one message through a queue. Expect
-- the received 'Msg' to echo the published payload.
recSingleMessage, recSingleMessage' :: Assertion
recSingleMessage = withGnatsd recSingleMessage'

recSingleMessage' =
    withNats defaultSettings [defaultURI] $ \nats -> do
        let topic'   = "test"
            replyTo' = Nothing
            payload' = "test message"

        (sid', queue) <- subscribe nats topic' Nothing
        publish nats topic' replyTo' payload'

        -- Wait for the message ...
        msg <- nextMsg queue
        sid'     @=? sid msg
        topic'   @=? topic msg
        replyTo' @=? replyTo msg
        payload' @=? payload msg

-- Subscribe on a topic and receive one message asynchronously. Expect
-- the message receiver to receive the expected 'Msg' data.
recSingleMessageAsync, recSingleMessageAsync' :: Assertion
recSingleMessageAsync = withGnatsd recSingleMessageAsync'

recSingleMessageAsync' =
    void $ withNats defaultSettings [defaultURI] $ \nats -> do
        let topic'   = "test"
            replyTo' = Nothing
            payload' = "test message"
        recData <- newEmptyMVar
        sid'    <- subscribeAsync nats topic' Nothing $ receiver recData
        publish nats topic' replyTo' payload'

        -- Wait for the MVar ...
        msg <- takeMVar recData
        sid'     @=? sid msg
        topic'   @=? topic msg
        replyTo' @=? replyTo msg
        payload' @=? payload msg
    where
      receiver :: MVar Msg -> Msg -> IO ()
      receiver = putMVar

-- | Subscribe to a topic, and send two messages to the topic. When
-- reading trying to read a third message from the queue, it shall
-- block. To handle the blocking 'timeout' is used.
recMessagesWithTmo, recMessagesWithTmo' :: Assertion
recMessagesWithTmo = withGnatsd recMessagesWithTmo'

recMessagesWithTmo' =
    void $ withNats defaultSettings [defaultURI] $ \nats -> do
        let topic'   = "test"
            payload1 = "test message"
            payload2 = "test message 2"

        (sid', queue) <- subscribe nats topic' Nothing
        publish nats topic' Nothing payload1
        publish nats topic' Nothing payload2

        -- Wait for the messages ...
        Just msg1 <- timeout oneSec $ nextMsg queue
        sid'     @=? sid msg1
        topic'   @=? topic msg1
        payload1 @=? payload msg1

        Just msg2 <- timeout oneSec $ nextMsg queue
        sid'     @=? sid msg2
        topic'   @=? topic msg2
        payload2 @=? payload msg2

        -- This time there shall be a timeout.
        reply <- timeout oneSec $ nextMsg queue
        Nothing @=? reply

-- | Request a topic. Request is a convenience function, it subscribe,
-- publish a message and waits for a reply. The replyTo topic is
-- random generated by the function.
requestMessage, requestMessage' :: Assertion
requestMessage = withGnatsd requestMessage'

requestMessage' =
    withNats defaultSettings [defaultURI] $ \nats -> do
        let topic'   = "test"
            payload' = "echo me"

        -- Register a handler for serving the request.
        void $ subscribeAsync nats topic' Nothing $
            \msg -> publish nats (fromJust $ replyTo msg) 
                            Nothing (payload msg)

        -- Make the request and compare the reply payload.
        msg <- request nats topic' payload'
        payload' @=? payload msg

-- | Subscribe to a topic, then unsubscribe to it before publishing
-- a message. No message shall show up in the queue.
unsubscribeToTopic, unsubscribeToTopic' :: Assertion
unsubscribeToTopic = withGnatsd unsubscribeToTopic'

unsubscribeToTopic' =
    void $ withNats defaultSettings [defaultURI] $ \nats -> do
        let topic' = "test"

        (sid', queue) <- subscribe nats topic' Nothing
        unsubscribe nats sid' Nothing
        publish nats topic' Nothing "shall never arrive"

        -- As the test case is unsubscribed, nothing shall show up.
        reply <- timeout oneSec $ nextMsg queue
        Nothing @=? reply

oneSec :: Int
oneSec = 1000000
