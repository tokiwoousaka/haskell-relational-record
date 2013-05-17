{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : Language.SQL.Keyword.Concat
-- Copyright   : 2013 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- Concatinations on 'Keyword' types
module Language.SQL.Keyword.Concat (
  unwords',

  sepBy, parenSepBy, defineBinOp,
  as, (<.>),

  (.||.),
  (.=.), (.<.), (.<=.), (.>.), (.>=.), (.<>.),
  and, or, in'
  ) where

import Prelude hiding (and, or)
import Data.List (intersperse)

import Language.SQL.Keyword.Type (Keyword (..), word, wordShow, unwordsSQL)


sepBy' :: [Keyword] -> Keyword -> [String]
ws `sepBy'` d =  map wordShow . intersperse d $ ws

unwords' :: [Keyword] -> Keyword
unwords' =  word . unwordsSQL

concat' :: [String] -> Keyword
concat' =  word . concat

sepBy :: [Keyword] -> Keyword -> Keyword
ws `sepBy` d = concat' $ ws `sepBy'` d

parenSepBy :: [Keyword] -> Keyword -> Keyword
ws `parenSepBy` d = concat' $ "(" : (ws `sepBy'` d) ++ [")"]

defineBinOp' :: Keyword -> Keyword -> Keyword -> Keyword
defineBinOp' op a b = concat' $ [a, b] `sepBy'` op

defineBinOp :: Keyword -> Keyword -> Keyword -> Keyword
defineBinOp op a b = word . unwords $ [a, b] `sepBy'` op

(<.>)  =  defineBinOp' "."

(.||.) =  defineBinOp "||"
(.=.)  =  defineBinOp "="
(.<.)  =  defineBinOp "<"
(.<=.) =  defineBinOp "<="
(.>.)  =  defineBinOp ">"
(.>=.) =  defineBinOp ">="
(.<>.) =  defineBinOp "<>"
as     =  defineBinOp AS
and    =  defineBinOp AND
or     =  defineBinOp OR
in'    =  defineBinOp IN

(<.>), (.||.), (.=.), (.<.), (.<=.), (.>.), (.>=.), (.<>.), as, and, or, in'
  :: Keyword -> Keyword -> Keyword

infixr 5 .||.
infixr 4 .=., .<., .<=., .>., .>=., .<>.
infix  4 `in'`
infixr 3 `and`
infixr 2 `or`