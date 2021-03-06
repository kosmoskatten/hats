module Main
    ( main
    ) where

import Test.Framework (Test, defaultMain, testGroup)
import Test.Framework.Providers.HUnit (testCase)
import Test.Framework.Providers.QuickCheck2 (testProperty)

import CallbackTests (callingCallbacks)
import JsonTests (recSingleJsonMessage, requestJsonMessage)
import NatsTests ( recSingleMessage
                 , recSingleMessageAsync
                 , recMessagesWithTmo
                 , requestMessage
                 , unsubscribeToTopic
                 )
import ReconnectionTests ( subscribeAndReconnect, connectionGiveUp
                         , authorizationFail, authorizationSuccess
                         )
import MessageProps (encodeDecodeMessage)

main :: IO ()
main = defaultMain testSuite

testSuite :: [Test]
testSuite =
    [ testGroup "Message property tests"
        [ testProperty "Encoding and decoding of Message"
                       encodeDecodeMessage
        ]
    , testGroup "Plain (non-JSON) NATS API tests"
        [ testCase "Reception of a single message"
                   recSingleMessage
        , testCase "Async reception of a single message"
                   recSingleMessageAsync
        , testCase "Reception of two messages, with timeout"
                   recMessagesWithTmo
        , testCase "Reception of a message using request"
                   requestMessage
        , testCase "Unsubscribe to a topic before publishing"
                   unsubscribeToTopic
        ]
    , testGroup "JSON NATS API tests"
        [ testCase "Reception of a single Json message"
                   recSingleJsonMessage
        , testCase "Reception of (modified) Json message using requestJson"
                   requestJsonMessage
        ]
    , testGroup "Callback tests"
        [ testCase "Test calling of connectedTo and disconnectedFrom"
                   callingCallbacks
        ]
    , testGroup "Connection tests"
        [ testCase "Test that subscription works after reconnect"
                   subscribeAndReconnect
        , testCase "Test that exception is thrown when giving up"
                   connectionGiveUp
        , testCase "Test that exceptions is thrown when fail authorization"
                   authorizationFail
        , testCase "Test that authorization succeed."
                   authorizationSuccess
        ]
    ]
