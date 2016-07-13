module Network.Nats
    ( Nats
    , Msg (..)
    , JsonMsg (..)
    , Sid
    , Payload
    , Topic
    , QueueGroup
    , SubQueue
    , ManagerSettings (..)
    , NatsException (URIError)
    , SockAddr
    , withNats
    , publish
    , publishJson
    , subscribe
    , subscribeAsync
    , subscribeAsyncJson
    , request
    , requestJson
    , unsubscribe
    , nextMsg
    , nextJsonMsg
    , defaultManagerSettings
    ) where

import Control.Exception (bracket, throwIO)
import Data.Either (isLeft)
import Data.Maybe (mapMaybe)
import Control.Monad (when)
import Network.URI (URI (..), parseAbsoluteURI)

import Network.Nats.Api ( Nats
                        , publish
                        , subscribe
                        , subscribeAsync
                        , request
                        , unsubscribe
                        , nextMsg
                        , initNats
                        , termNats
                        )
import Network.Nats.ConnectionManager ( ManagerSettings (..)
                                      , SockAddr
                                      , defaultManagerSettings
                                      )
import Network.Nats.JsonApi ( JsonMsg (..)
                            , publishJson
                            , requestJson
                            , subscribeAsyncJson
                            , nextJsonMsg
                            )
import Network.Nats.Subscriber (Msg (..), SubQueue)
import Network.Nats.Types ( Sid
                          , Payload
                          , Topic
                          , QueueGroup
                          , NatsException (..)
                          )

withNats :: ManagerSettings -> [String] -> (Nats -> IO a) -> IO a
withNats config ss action = do
    let uris = convertURIs ss
    when (isLeft uris) $ do
        let (Left err) = uris
        throwIO $ URIError err
    
    let (Right uris') = uris
    bracket (initNats config uris') termNats action

convertURIs :: [String] -> Either String [URI]
convertURIs [] = Left "Must be at least one URI"
convertURIs ss =
    let uris  = toURIs ss
        eqLen = length ss == length uris
    in if eqLen then Right uris
                else Left "Malformed URI(s)"
    where
      toURIs = filter expectedScheme . mapMaybe parseAbsoluteURI

expectedScheme :: URI -> Bool
expectedScheme uri = uriScheme uri == "nats:" || uriScheme uri == "tls:"

