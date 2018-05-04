{-# LANGUAGE KindSignatures  #-}
{-# LANGUAGE RecordWildCards #-}

module Leaderboard.RegistrationTests
  ( registrationTests
  ) where

import           Control.Lens               ((&), (.~))
import           Control.Monad.IO.Class     (liftIO)
import           Control.Monad.Trans.Class  (lift)
import           Data.Text                  (Text)
import           Database.PostgreSQL.Simple (ConnectInfo (..))
import           Network.HTTP.Client.TLS    (newTlsManager)
import           Network.HTTP.Types.Status  (forbidden403)
import           Servant.Client             (BaseUrl (BaseUrl),
                                             ClientEnv (ClientEnv), ClientM,
                                             Scheme (Https), ServantError (..),
                                             runClientM)

import           Hedgehog                   (Callback (..), Command (Command),
                                             Gen, HTraversable (htraverse),
                                             Property, PropertyT, annotateShow,
                                             executeSequential, failure, forAll,
                                             property, (===))
import qualified Hedgehog.Gen               as Gen
import qualified Hedgehog.Range             as Range

import           Test.Tasty                 (TestName, TestTree, testGroup)
import           Test.Tasty.Hedgehog        (testProperty)

import           Leaderboard.TestClient     (LeaderboardClient (..),
                                             mkLeaderboardClient)
import           Leaderboard.TestServer     (withLeaderboard)
import           Leaderboard.Types          (ApplicationOptions (..),
                                             RegisterPlayer (..), dbConnInfo,
                                             _connectDatabase)

registrationTests
  :: ApplicationOptions
  -> TestTree
registrationTests ao =
  let
    runTest' = runTest ao
  in
    testGroup "registration" [
      runTest' "register-first" propRegFirst
    ]

runTest
  :: ApplicationOptions
  -> TestName
  -> (ClientEnv -> PropertyT IO ())
  -> TestTree
runTest ao name f =
  testProperty name . property $ do
    dbName <- forAll $ Gen.string (Range.constant 10 10) Gen.alpha
    let ao' = ao & dbConnInfo . _connectDatabase .~ dbName
    withLeaderboard ao' f

genNonEmptyUnicode
  :: Gen Text
genNonEmptyUnicode =
  Gen.text (Range.linear 1 100) Gen.unicode

genRegPlayerRandomAdmin
  :: Gen RegisterPlayer
genRegPlayerRandomAdmin =
  LeaderboardRegistration
    <$> genNonEmptyUnicode
    <*> genNonEmptyUnicode
    <*> genNonEmptyUnicode
    <*> (Just <$> Gen.bool)

--------------------------------------------------------------------------------
-- REGISTER FIRST
--------------------------------------------------------------------------------

newtype RegFirstState (v :: * -> *) =
  RegFirstState Bool
  deriving (Eq, Show)

initialState :: RegFirstState v
initialState = RegFirstState False

newtype RegFirst (v :: * -> *) =
  RegFirst RegisterPlayer
  deriving (Eq, Show)

instance HTraversable RegFirst where
  htraverse _ (RegFirst rp) = pure (RegFirst rp)

cRegFirst
  :: ClientEnv
  -> Command Gen (PropertyT IO) RegFirstState
cRegFirst env =
  let
    gen = const . Just . fmap RegFirst $ genRegPlayerRandomAdmin
    execute (RegFirst rp) = lift . flip runClientM env $ lcRegisterFirst mkLeaderboardClient rp
  in
    Command gen execute [
      Update $ \_in _c _out -> RegFirstState True
    , Ensure $ \(RegFirstState sOld) (RegFirstState sNew) _input r ->
        case r of
          Right _ -> sOld === False >> sNew === True
          Left FailureResponse{..} ->
            sOld === True
            >> sNew === True
            >> responseStatus === forbidden403
          Left e -> annotateShow e >> failure
    ]

propRegFirst
  :: ClientEnv
  -> PropertyT IO ()
propRegFirst env = do
  commands <- forAll $
    Gen.sequential (Range.linear 1 100) initialState [cRegFirst env]
  executeSequential initialState commands
