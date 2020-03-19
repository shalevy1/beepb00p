{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

module Ipynb where

import Control.Monad ((>=>))
import Data.Maybe    (isJust)

import Hakyll (Item, Compiler, Context, Context(..), ContextField(StringField), getResourceString, itemIdentifier, getMetadataField)

import Common (compileWithFilter, (|>), (|.))

import Debug.Trace (trace)


-- TODO hmm, that should probably be pre commit hook for content git repo?
-- wouldn't hurt to run again and check?
-- python3 ./ipynb_output_filter.py <lagr.ipynb >lagr2.ipynb 

-- TODO could be implemented as a preprocessor in ipython notebook?
stripPrivateTodos :: Item String -> Compiler (Item String)
stripPrivateTodos = compileWithFilter "grep" ["-v", "NOEXPORT"]


-- ugh, images do not really work in markdown..
-- , "--to", "markdown"
-- TODO patch notebook and add %matplotlib inline automalically?
-- TODO --allow-errors??

ipynbRun :: Item String -> Compiler (Item String)
ipynbRun item = do
  let iid = itemIdentifier item
  maybe_allow_errors <- getMetadataField iid "allow_errors"
  let allow_errors = isJust maybe_allow_errors

  maybe_with_data    <- getMetadataField iid "with_data"
  let with_data    = isJust maybe_with_data

  -- TODO unhardcode _site? Configuration { destinationDirectory = "_site"
  -- TODO I suspect that proper way to do it is for Item to hold String + list of extra files...
  -- for now just hack it
  let cmd = if with_data then "with_data" else "misc/compile-ipynb"
  let args = (if with_data then ["misc/compile-ipynb"] else []) ++ ["--output-dir", "_site", "--item", show iid]
  let extra_args = if allow_errors then ["--allow-errors"] else []
  res <- compileWithFilter cmd (args ++ extra_args) item
  return res

ipynbCompile = stripPrivateTodos >=> ipynbRun
ipynbCompiler = getResourceString >>= ipynbCompile

-- TODO release ipython stuff in a separate file so it's easy to share
