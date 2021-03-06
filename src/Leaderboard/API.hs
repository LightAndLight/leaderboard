{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators         #-}

module Leaderboard.API where

import           Control.Monad.Except        (MonadError)
import           Control.Monad.Log           (MonadLog)
import           Control.Monad.Log.Label     (Label)
import           Control.Monad.Reader        (MonadReader)
import           Control.Monad.Trans.Control (MonadBaseControl)
import           Data.Proxy                  (Proxy (Proxy))
import           Servant                     (ServantErr, ServerT, (:<|>)((:<|>)))
import           Servant.Auth                (JWT)
import           Servant.Auth.Server         (JWTSettings)

import           Leaderboard.API.Player      (PlayerAPI, playerServer)
import           Leaderboard.API.Match      (MatchAPI, matchServer)
import           Leaderboard.Env             (HasDbConnPool)

type LeaderboardAPI auths =
       PlayerAPI auths
  :<|> MatchAPI auths

leaderboardAPI
  :: Proxy (LeaderboardAPI '[JWT])
leaderboardAPI = Proxy

leaderboardServer
  :: ( HasDbConnPool env
     , MonadBaseControl IO m
     , MonadReader env m
     , MonadError ServantErr  m
     , MonadLog Label m
     )
  => JWTSettings
  -> ServerT (LeaderboardAPI auths) m
leaderboardServer jwts =
       playerServer jwts
  :<|> matchServer
