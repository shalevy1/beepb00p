--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll

import Control.Applicative (empty)
import Control.Monad ((>=>))
import Data.Maybe (fromJust, fromMaybe, catMaybes)
import System.FilePath (replaceExtension, (</>))

import Text.Pandoc (readOrg, Pandoc(..), docTitle, docDate, Meta, Inline)
import Text.Pandoc.Shared (stringify)
import Text.Pandoc.Options (def, writerVariables, writerTableOfContents)
import           Control.Applicative ((<|>))

import Hakyll.Web.Pandoc
import Debug.Trace (trace)

baseUrl = "https://beepb00p.xyz"

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "Mildly entertaining"
    , feedAuthorName  = "karlicoss"
    , feedAuthorEmail = "karlicoss@gmail.com"
    , feedDescription = "feed" -- TODO ?
    , feedRoot        = baseUrl -- TODO how to test feed?
    }


-- TODO think about naming?
data Overrides = Overrides { upid :: Maybe String, date :: Maybe String, title :: Maybe String, summary :: Maybe String }


defaultOverrides = Overrides { upid = Nothing, date = Nothing, title = Nothing, summary = Nothing }


-- TODO right, get rid of these in favor of .metadata files?
overrides = [ ("meta/me.md"                    , dovr { upid    = j "me" } )
            , ("meta/index.html"               , dovr { upid    = j "index" } )
            , ("content/lagrangians.ipynb"     , dovr { upid    = j "they_see_me_flowing"
                                                      , date    = j "2019-01-01" -- FIXME
                                                      , title   = j "They see me flowin' they hatin'"
                                                      , summary = j "Visualising some unconventional Lagrangians and their Hamiltonian flows."
                                                      })
            , ("content/grasp.md"              , dovr { upid    = j "org_grasp"
                                                      , summary = j "How to capture information from your browser and stay sane"
                                                      })
            , ("content/sleep-tracking.md"     , dovr { upid    = j "sleep_tracking"
                                                      , summary = j "How not to do it"
                                                      })
            , ("content/quantified-mind.md"    , dovr { upid    = j "quantified_mind"
                                                      , summary = j "Exploiting javascript to reverse engineer cognitive score"
                                                      })
            , ("content/ipynb-singleline.ipynb", dovr { upid    = j "ipynb_singleline"
                                                      , title   = j "Forcing IPython to display multiple equations in single line"
                                                      , summary = j "How I sacrificed few hours of my life for aethetics"
                                                      })
            , ("content/recycling-is-hard.md"  , dovr { upid    = j "recycling_is_hard"
                                                      })
            ] :: [(String, Overrides)] where
  dovr = defaultOverrides
  j = Just

getOverrides :: String -> Maybe Overrides
getOverrides x = lookup x overrides -- TODO maybe in that case empty? dangerous though... for disqus id

overridesCtx :: Context a
overridesCtx = Context makeItem where
  -- ok, so it's name, parameters, item
  makeItem fname a item = case ovd of
      Just x  -> return $ StringField x
      Nothing -> empty
    where
    getter fname
      | fname == "upid"        = upid
      | fname == "date"        = date
      | fname == "title"       = title
      | fname == "summary"     = summary
      | otherwise              = \_ -> Nothing -- TODO ??

    ovd = do
      ov <- getOverrides $ toFilePath $ itemIdentifier item
      getter fname ov

-- upid
-- should be path independent
-- should be extension independent
-- ok, so a static map for now
-- TODO make sure they are unchanged? dump them?
-- TODO warn if some are gone too?



pandocMeta :: (Meta -> [Inline]) -> (Item Pandoc -> Compiler String)
pandocMeta extractor Item {itemBody=Pandoc meta _} = return $ stringify $ extractor meta -- TODO proper html??

-- TODO extract that stuff somewhere and share??
orgFileTags = field "filetags" (\p -> return "TODO FILETAGS")
orgAuthor = constField "author" "Dima" -- TODO docAuthors??
orgTitle = field "title" $ pandocMeta docTitle
orgDate = field "date" $ pandocMeta docDate

pandocContext :: Context Pandoc
pandocContext = orgFileTags <> orgAuthor <> orgTitle <> orgDate

-- TODO ugh. surely it can't be that ugly right?
data PandocX = PandocX Pandoc String

combineItems :: (a -> b -> c) -> Item a -> Item b -> Item c
combineItems f Item{itemBody=ba, itemIdentifier=ii} Item{itemBody=bb} = Item {itemBody=f ba bb, itemIdentifier=ii}

combineContexts :: Context Pandoc -> Context String -> Context PandocX
combineContexts (Context f) (Context g) = Context $ \k a Item{itemBody=PandocX pdoc rendered} -> f k a Item {itemBody=pdoc, itemIdentifier=""} <|> g k a Item {itemBody=rendered, itemIdentifier=""} -- TODO break down item ;

-- myContext :: Context PandocX
-- myContext = combineContexts pandocContext defaultContext

----- ipython stuff

-- thanks to https://github.com/gibiansky/blog/blob/668a5bf7ae6815a20dd6d57c900318e34c959c13/Compilers.hs
compileWithFilter :: String -> [String] -> Item String -> Compiler (Item String)
compileWithFilter cmd args = withItemBody (unixFilter cmd args)

-- TODO hmm, that should probably be pre commit hook for content git repo?
-- wouldn't hurt to run again and check?
-- python3 ./ipynb_output_filter.py <lagr.ipynb >lagr2.ipynb 

stripPrivateTodos :: Item String -> Compiler (Item String)
stripPrivateTodos = compileWithFilter "grep" ["-v", "TODO P "]

ipynbFilterOutput :: Item String -> Compiler (Item String)
ipynbFilterOutput = compileWithFilter cmd args
  where cmd = "python3"
        args = [ "/L/soft/ipynb_output_filter/ipynb_output_filter.py" ] -- TODO use nbstripout??


-- ugh, images do not really work in markdown..
-- , "--to", "markdown"
-- TODO patch notebook and add %matplotlib inline automalically?
ipynbRun :: Item String -> Compiler (Item String)
ipynbRun = compileWithFilter command arguments
  where command = "jupyter"
        arguments = ["nbconvert"
                    , "--execute"
                    , "--TagRemovePreprocessor.remove_cell_tags={\"noexport\"}" -- TODO emacs tags?
                    , "--to", "html", "--template", "misc/mybasic.tpl"
                    , "--stdin"
                    , "--stdout"
                    ]

-- (<&>)  = flip fmap
-- infixl 1 <&>


renameItem :: (String -> String) -> Item a -> Item a
renameItem f i =  i { itemIdentifier = new_id } where
  old_id = itemIdentifier i
  old_version = identifierVersion old_id
  new_id = setVersion old_version $ (fromFilePath $ f $ toFilePath old_id)

-- TODO ugh itemIdentifier is not exported???
-- renameItem f x = x { itemIdentifier = new_id } where
--   old_id = itemIdentifier x -- TODO do I need lens?..
--   old_path = identifierPath old_id
--   new_path = f old_path
--   new_id = old_id { identifierPath = new_path }

ipynbCompile = stripPrivateTodos >=> ipynbFilterOutput >=> ipynbRun
  -- ipy <- ipynbRun i  -- x <&> (renameItem (\f -> replaceExtension f ".md")) -- ipynbFilterOutput >> ipynbRun
  -- let ipy_md = renameItem (\f -> replaceExtension f ".md") ipy -- change the extension to trick pandoc...
  -- pandoc <- readPandoc ipy_md
  -- let html = writePandoc pandoc
  -- let res = renameItem (\f -> replaceExtension f ".ipynb") html 
  -- return ipy

-- TODO release ipython stuff in a separate file so it's easy to share

----- end of ipython stuff


---- start of org mode stuff
  
-- pandoc doesn't seem to be capable of handling many org clases.. 
-- https://github.com/jgm/pandoc/blob/f3080c0c22470e7ecccbef86c1cd0b1339a6de9b/src/Text/Pandoc/Readers/Org/ExportSettings.hs#L61
renderOrg :: Item String -> Compiler (Item String)
renderOrg   = compileWithFilter "misc/compile-org" []  -- trace (toFilePath $ itemIdentifier x) $ undefined

extractBody = compileWithFilter "xmllint" ["--html", "--xpath", "//body/node()", "--format", "-"]

orgCompile = renderOrg >=> extractBody


--- end of org mode stuff

main :: IO ()
main = hakyll $ do
    match ("meta/favicon.ico" .||. "meta/robots.txt") $ do
        route   $ gsubRoute "meta/" (const "")
        compile   copyFileCompiler


    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler -- TODO eh? do not compress?


    -- TODO shit this is problematic for all simple web servers, they think it's octet-stream :(
    let chopOffRoute thing = gsubRoute thing (const "" )
          `composeRoutes` setExtension "html" -- TODO fucking hell it's annoying. couldn't force github pages or preview server to support that
  
    let postRoute = chopOffRoute "content/"

    match (fromList ["meta/me.md"]) $ do
        route   $ gsubRoute "meta/" (const "") `composeRoutes` setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    let postCompiler ctx =
            saveSnapshot "feed-body"
            >=> loadAndApplyTemplate "templates/post.html" ctx
            >=> loadAndApplyTemplate "templates/default.html" ctx
            >=> relativizeUrls

    let style x = constField ("style_" ++ x) ""  -- kinda like a flag
    let org   = style "org"
    let ipynb = style "ipynb"
    let md    = style "md"


    let orgCompiler   = getResourceString >>= orgCompile
    let ipynbCompiler = getResourceString >>= ipynbCompile
    -- TODO careful not to pick this file up when we have more org posts
    -- perhaps should just move the link out of content root


    -- TODO unify these 'special' pages
    -- -- let ff  = constField "css" "hello"
    -- let ff = field "css" $ \x -> itemBody x
    -- let ctx = postCtx <> listField "extra_styles" ff (return ["HELLO", "WHOOPS"])
    match "content/special/ideas.org" $ do
        let ctx = postCtx <> org
        route   $ chopOffRoute "content/special/"
        compile $ orgCompiler
            >>= postCompiler ctx

    match "content/special/notes.org" $ do
        let ctx = postCtx <> org
        route   $ chopOffRoute "content/special/"
        compile $ orgCompiler
            >>= postCompiler ctx

    -- TODO think how to infer date?
    match "content/*.md" $ do
        let ctx = postCtx <> md
        route   postRoute
        compile $ pandocCompiler
            >>= postCompiler ctx

-- TODO in org mode files, date should be present
-- if it's not, complain, but the whole thing shouldn't fail!

    -- TODO make a script to check that links are reachable
    -- TODO posts/etc is lame, use top level
    -- TODO tags would be nice...
    match "content/*.ipynb" $ do
        let ctx = postCtx <> ipynb
        route   postRoute
        compile $ ipynbCompiler
              >>= postCompiler ctx

    match "content/*.org" $ do
        let ctx = postCtx <> org
        route   postRoute
        compile $ orgCompiler
              >>= postCompiler ctx

-- TODO appendIndex??https://github.com/aherrmann/jekyll_style_urls_with_hakyll_examples/blob/master/site.hs
-- https://github.com/turboMaCk/turboMaCk.github.io/blob/develop/site.hs#L61 ??
-- TODO reference to how to read my posts?? e.g. what todo states mean etc

    -- create ["archive.html"] $ do
    --     route idRoute
    --     compile $ do
    --         posts <- recentFirst =<< loadAll "posts/*"
    --         let archiveCtx =
    --                 listField "posts" postCtx (return posts) `mappend`
    --                 constField "title" "Archives"            `mappend`
    --                 defaultContext

    --         makeItem ""
    --             >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
    --             >>= loadAndApplyTemplate "templates/default.html" archiveCtx
    --             >>= relativizeUrls

    -- let loadPosts = loadAll ("content/*.md" .||. "content/*.ipynb")
    let patterns = "content/*.md" .||. "content/*.ipynb" .||. "content/*.org"

    match "meta/index.html" $ do
        route   $ gsubRoute "meta/" (const "")
        compile $ do
            -- TODO sorting: I guess we want datetime in case of multiple posts on the same day
            posts <- recentFirst =<< loadAll patterns
            let indexCtx =
                    listField "posts" postCtx (return posts)
                    <> constField "title" "Home"
                    <> defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    -- TODO atom -- published, updated , I guess handle carefully so there aren't too many annoying updates
    -- TODO include latest only?
    -- TODO not sure if need to prettify description
    -- TODO use 'content' field??
    let feedCtx = postCtx <> bodyField "description"
    -- https://jip.dev/posts/post-feed-in-hakyll/
    -- let feedPosts = loadAllSnapshots patterns "feed-body"
    let feedPosts = loadAll patterns

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            posts <- feedPosts
            renderAtom myFeedConfiguration feedCtx posts

    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            posts <- feedPosts
            renderRss myFeedConfiguration feedCtx posts

    match "templates/*" $ compile templateBodyCompiler

-- ugh. there must be an easier way...
transformCtx :: String -> String -> (ContextField -> ContextField) -> Context a -> Context a
transformCtx name oldname transform (Context c) = Context $ \k a i -> do
  if k /= name
    then c k a i
    else do
      fld <- c oldname a i
      return $ transform fld

issoIdCtx = transformCtx "issoid" "upid" mapfield where
  mapfield (StringField fld) = StringField $ "isso_" ++ fld
  mapfield _ = error "unsupported field type"

postCtx :: Context String
-- left takes precedence
postCtx = issoIdCtx (overridesCtx <> defaultContext)

