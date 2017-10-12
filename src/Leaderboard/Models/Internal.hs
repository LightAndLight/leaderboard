{-# language DeriveGeneric #-}
{-# language FlexibleInstances #-}
{-# language MultiParamTypeClasses #-}
{-# language OverloadedStrings #-}
{-# language StandaloneDeriving #-}
{-# language TemplateHaskell #-}
{-# language TypeFamilies #-}
{-# language TypeOperators #-}
module Leaderboard.Models.Internal where

import Control.Lens (makeLenses)
import Data.Aeson
import Data.Text
import Database.Beam

data RatingT f
  = Rating
  { _ratingId :: Columnar f (Auto Int)
  , _ratingRating :: Columnar f Double
  , _ratingDev :: Columnar f Double
  , _ratingVol :: Columnar f Double
  , _ratingInactivity :: Columnar f Int
  , _ratingAge :: Columnar f Int
  }
  deriving Generic

type Rating = RatingT Identity
type RatingId = PrimaryKey RatingT Identity

deriving instance Eq Rating
deriving instance Show Rating
deriving instance Ord Rating

deriving instance Eq RatingId
deriving instance Show RatingId
deriving instance Ord RatingId

instance Beamable RatingT
instance Table RatingT where
  data PrimaryKey RatingT f = RatingId (Columnar f (Auto Int)) deriving Generic
  primaryKey = RatingId . _ratingId

instance Beamable (PrimaryKey RatingT)


data PlayerT f
  = Player
  { _playerId :: Columnar f (Auto Int)
  , _playerFirstName :: Columnar f Text
  , _playerLastName :: Columnar f (Maybe Text)
  , _playerEmail :: Columnar f Text
  }
  deriving Generic

type Player = PlayerT Identity
type PlayerId = PrimaryKey PlayerT Identity

instance ToJSON Player where
  toJSON (Player (Auto a) b c d) =
    object
      [ "id" .= a
      , "firstName" .= b
      , "lastName" .= c
      , "email" .= d
      ]

deriving instance Eq Player
deriving instance Show Player
deriving instance Ord Player

deriving instance Eq PlayerId
deriving instance Show PlayerId
deriving instance Ord PlayerId

instance Beamable PlayerT
instance Table PlayerT where
  data PrimaryKey PlayerT f = PlayerId (Columnar f (Auto Int)) deriving Generic
  primaryKey = PlayerId . _playerId

instance Beamable (PrimaryKey PlayerT)


data LadderT f
  = Ladder
  { _ladderId :: Columnar f (Auto Int)
  , _ladderName :: Columnar f Text
  , _ladderOwner :: PrimaryKey PlayerT f
  }
  deriving Generic

deriving instance Eq Ladder
deriving instance Show Ladder
deriving instance Ord Ladder

deriving instance Eq LadderId
deriving instance Show LadderId
deriving instance Ord LadderId

type Ladder = LadderT Identity
type LadderId = PrimaryKey LadderT Identity

instance Beamable LadderT
instance Table LadderT where
  data PrimaryKey LadderT f = LadderId (Columnar f (Auto Int)) deriving Generic
  primaryKey = LadderId . _ladderId

instance Beamable (PrimaryKey LadderT)


data PlayerToLadderT f
  = PlayerToLadder
  { _p2lPlayer :: PrimaryKey PlayerT f
  , _p2lLadder :: PrimaryKey LadderT f
  , _p2lRating :: PrimaryKey RatingT f
  }
  deriving Generic

deriving instance Eq PlayerToLadder
deriving instance Show PlayerToLadder
deriving instance Ord PlayerToLadder

type PlayerToLadder = PlayerToLadderT Identity

instance Beamable PlayerToLadderT
instance Table PlayerToLadderT where
  data PrimaryKey PlayerToLadderT f
    = PlayerToLadderKey (PrimaryKey PlayerT f) (PrimaryKey LadderT f)
      deriving Generic
  primaryKey = PlayerToLadderKey <$> _p2lPlayer <*> _p2lLadder

instance Beamable (PrimaryKey PlayerToLadderT)

makeLenses ''PlayerT
makeLenses ''RatingT
makeLenses ''LadderT
makeLenses ''PlayerToLadderT
