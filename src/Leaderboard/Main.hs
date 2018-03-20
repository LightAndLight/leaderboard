module Leaderboard.Main where

import           Control.Exception
import           Control.Monad.Log          (LogType (..), levelDebug,
                                             makeDefaultLogger,
                                             simpleTimeFormat)
import           Control.Retry              (exponentialBackoff)
import           Data.Either
import           Data.Monoid
import           Data.Word                  (Word16)
import           Database.PostgreSQL.Simple
import           Network.Wai.Handler.Warp
import           Options.Applicative
import           System.Environment
import           URI.ByteString

import qualified Data.ByteString.Char8      as C8
import qualified Data.Text                  as T

import           Leaderboard.Application    (leaderboard)
import           Leaderboard.Env            (Env)
import           Leaderboard.Queries        (getOrCreateJwk)

data ApplicationOptions
  = ApplicationOptions
  { aoDbHost :: String
  , aoDbPort :: Word16
  , aoDbUser :: String
  , aoDbName :: String
  , aoPort   :: Int
  }

applicationOptionsParser :: Parser ApplicationOptions
applicationOptionsParser =
  ApplicationOptions <$>
    dbHost <*> dbPort <*> dbUser <*> dbName <*> port
  where
    dbHost = strOption (long "db_host" <> help "Database host name" <> metavar "HOST")
    dbPort = fmap read (strOption $ long "db_port" <> help "Database port" <> metavar "DB_PORT")
    dbUser = strOption (long "db_user" <> help "Database user" <> metavar "DB_USER")
    dbName = strOption (long "db_name" <> help "Database name" <> metavar "DB_NAME")
    port = fmap read (strOption $ long "port" <> help "Webapp port" <> metavar "PORT")

parserInfo :: ParserInfo ApplicationOptions
parserInfo =
  info
    (applicationOptionsParser <**> helper)
    (fullDesc <> progDesc "Run the leaderboard webapp")

main :: IO ()
main = do
  putStrLn "leaderboard started"
  opts <- execParser parserInfo
  password <- getEnv "DB_PASS"
  logger <-
    makeDefaultLogger simpleTimeFormat (LogStdout 4096) levelDebug ()

  let
    connInfo =
      ConnectInfo
      { connectHost = aoDbHost opts
      , connectPort = aoDbPort opts
      , connectUser = aoDbUser opts
      , connectPassword = password
      , connectDatabase = aoDbName opts
      }

    mkEnv = do
      putStrLn "Connecting to database.."
      c <- connect connInfo
      jwk <- getOrCreateJwk c
      pure $ Environment c jwk

  bracket
    (recovering
      (constantDelay 1000)
      [ logRetries
          (\SomeException{} -> pure True)
          (\b e r -> putStrLn $ defaultLogMsg b e r)
      ]
      (const mkEnv))
    (\env -> do
        putStrLn "Connected to database."
        run (aoPort opts) $ leaderboard env logger)
    (close . _envConnection)
