{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

module Org where

import Control.Applicative (empty)
import Control.Monad ((>=>))
import Data.Char (toLower)
import Data.List (intercalate)
import Data.List.Split (splitOn)
import Data.Maybe (fromJust, fromMaybe, catMaybes, isJust)
import Debug.Trace (trace)
import System.FilePath (takeExtension, replaceExtension, (</>), makeRelative, isRelative, takeDirectory)


import Hakyll (Item, Compiler, Context, Context(..), ContextField(StringField), loadSnapshot, itemBody, itemIdentifier, getResourceString, saveSnapshot, getMetadataField)

import Common (compileWithFilter, (|>), (|.))


orgCompile :: Item String -> Compiler (Item String)
orgCompile item  = do
  -- TODO eh, kinda copy pasted from Ipynb.hs...
  let iid = show $ itemIdentifier item
  let path = makeRelative "content/" iid
  _ <- if path == iid then fail "Expected path relative to content/" else return () -- meh. is that really the right way?

  meta <- getMetadataField (itemIdentifier item) "check_ids"
  let check_ids = isJust meta

  let spath = makeRelative "special/" path -- we flatten 'special hierarchy'
  let wdir = "_site" </> takeDirectory spath

  let args = ["--output-dir", wdir] ++ (if check_ids then ["--check-ids"] else [])
  compileWithFilter "misc/compile_org.py" args item

raw_org_key = "raw_org"
meta_start = "#+"
meta_sep   = ": "

type OrgMetas = [(String, String)]
type OrgBody = String

-- TODO ugh. very hacky...
orgMetadatas :: OrgBody -> OrgMetas
orgMetadatas = lines |. map tryMeta |. catMaybes
  where
    tryMeta :: String -> Maybe (String, String)
  -- TODO catMaybe?
    tryMeta line = do
      -- TODO ugh. a bit ugly...
      let split = splitOn meta_start line
      case split of
        ("": rem) ->
           let split2 = splitOn meta_sep $ concat rem in
             case split2 of
               -- we intercalate here since colons could be in title
               -- TODO ugh. perhaps should have used regex instead
               (fieldname: rem2) -> Just (fieldname |> map toLower, intercalate meta_sep rem2)
               _ -> Nothing
        _ -> Nothing

orgMetas :: Context String
orgMetas = Context $ \key _ item -> do
  let idd = itemIdentifier item
  let path = show idd
  if takeExtension path /= ".org" then empty else do
    raw_org :: Item String  <- loadSnapshot idd raw_org_key
    let metas = orgMetadatas $ itemBody raw_org
    let meta = lookup key metas
    maybe empty (StringField |. return) meta


-- TODO that's pretty horrible... maybe I need a special item type... and combine compilers?
orgCompiler   = do
  res <- getResourceString
  _ <- saveSnapshot raw_org_key res
  orgCompile res
-- TODO careful not to pick this file up when we have more org posts
-- perhaps should just move the link out of content root


-- import Text.Pandoc.Shared (stringify)
-- import Text.Pandoc.Options (def, writerVariables, writerTableOfContents)

-- import Hakyll.Web.Pandoc
-- import Text.Pandoc (readOrg, Pandoc(..), docTitle, docDate, Meta, Inline)
-- pandocMeta :: (Meta -> [Inline]) -> (Item Pandoc -> Compiler String)
-- pandocMeta extractor Item {itemBody=Pandoc meta _} = return $ stringify $ extractor meta -- TODO proper html??

-- -- TODO extract that stuff somewhere and share??
-- orgFileTags = field "filetags" (\p -> return "TODO FILETAGS")
-- orgAuthor = constField "author" "Dima" -- TODO docAuthors??
-- orgTitle = field "title" $ pandocMeta docTitle
-- orgDate = field "date" $ pandocMeta docDate

-- pandocContext :: Context Pandoc
-- pandocContext = orgFileTags <> orgAuthor <> orgTitle <> orgDate

-- -- TODO ugh. surely it can't be that ugly right?
-- data PandocX = PandocX Pandoc String

-- combineItems :: (a -> b -> c) -> Item a -> Item b -> Item c
-- combineItems f Item{itemBody=ba, itemIdentifier=ii} Item{itemBody=bb} = Item {itemBody=f ba bb, itemIdentifier=ii}

-- combineContexts :: Context Pandoc -> Context String -> Context PandocX
-- combineContexts (Context f) (Context g) = Context $ \k a Item{itemBody=PandocX pdoc rendered} -> f k a Item {itemBody=pdoc, itemIdentifier=""} <|> g k a Item {itemBody=rendered, itemIdentifier=""} -- TODO break down item ;

-- TODO readPandocWith??

-- myContext :: Context PandocX
-- myContext = combineContexts pandocContext defaultContext

-- pandoc doesn't seem to be capable of handling many org clases.. 
-- https://github.com/jgm/pandoc/blob/f3080c0c22470e7ecccbef86c1cd0b1339a6de9b/src/Text/Pandoc/Readers/Org/ExportSettings.hs#L61
