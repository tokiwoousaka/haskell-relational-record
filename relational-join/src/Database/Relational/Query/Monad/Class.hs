{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- |
-- Module      : Database.Relational.Query.Monad.Class
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines query building interface classes.
module Database.Relational.Query.Monad.Class (
  -- * Query interface classes
  MonadQualify (..),
  MonadQuery (..), MonadAggregate (..),

  on, onP, wheres, wheresP,
  groupBy, having, havingP
  ) where

import Database.Relational.Query.Expr (Expr)
import Database.Relational.Query.Projection (Projection)
import Database.Relational.Query.Aggregation (Aggregation)
import Database.Relational.Query.Projectable (expr)
import Database.Relational.Query.Sub (SubQuery, Qualified)

import Database.Relational.Query.Internal.Product (NodeAttr)

-- | Query building interface.
class (Functor m, Monad m) => MonadQuery m where
  -- | Add restriction to last join.
  restrictJoin :: Expr Projection (Maybe Bool) -- ^ 'Expr' 'Projection' which represent restriction
               -> m ()                         -- ^ Restricted query context
  -- | Add restriction to this query.
  restrictQuery :: Expr Projection (Maybe Bool) -- ^ 'Expr' 'Projection' which represent restriction
                -> m ()                         -- ^ Restricted query context
  -- | Unsafely join subquery with this query.
  unsafeSubQuery :: NodeAttr           -- ^ Attribute maybe or just
                 -> Qualified SubQuery -- ^ 'SubQuery' to join
                 -> m (Projection r)   -- ^ Result joined context and 'SubQuery' result projection.
  -- unsafeMergeAnotherQuery :: NodeAttr -> m (Projection r) -> m (Projection r)

-- | Lift interface from base qualify monad.
class (Functor q, Monad q, MonadQuery m) => MonadQualify q m where
  -- | Lift from qualify monad 'q' into 'MonadQuery' m.
  --   Qualify monad qualifies table form 'SubQuery'.
  liftQualify :: q a -> m a

-- | Aggregated query building interface extends 'MonadQuery'.
class MonadQuery m => MonadAggregate m where
  -- | Add /group by/ term into context and get aggregated projection.
  aggregateKey :: Projection r      -- ^ Projection to add into group by
               -> m (Aggregation r) -- ^ Result context and aggregated projection
  -- | Add restriction to this aggregated query.
  restrictAggregatedQuery :: Expr Aggregation (Maybe Bool) -- ^ 'Expr' 'Aggregation' which represent restriction
                          -> m ()                          -- ^ Restricted query context

-- | Add restriction to last join.
on :: MonadQuery m => Expr Projection (Maybe Bool) -> m ()
on =  restrictJoin

-- | Add restriction to last join. Projection type version.
onP :: MonadQuery m => Projection (Maybe Bool) -> m ()
onP =  on . expr

-- | Add restriction to this query.
wheres :: MonadQuery m => Expr Projection (Maybe Bool) -> m ()
wheres =  restrictQuery

-- | Add restriction to this query. Projection type version.
wheresP :: MonadQuery m => Projection (Maybe Bool) -> m ()
wheresP =  wheres . expr

-- | Add /group by/ term into context and get aggregated projection.
groupBy :: MonadAggregate m
        => Projection r      -- ^ Projection to add into group by
        -> m (Aggregation r) -- ^ Result context and aggregated projection
groupBy =  aggregateKey

-- | Add restriction to this aggregated query.
having :: MonadAggregate m => Expr Aggregation (Maybe Bool) -> m ()
having =  restrictAggregatedQuery

-- | Add restriction to this aggregated query. Aggregation type version.
havingP :: MonadAggregate m => Aggregation (Maybe Bool) -> m ()
havingP =  having . expr
