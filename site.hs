--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid            ((<>))
import           Hakyll
import qualified Data.Map as M
import           Text.Pandoc.Options
import           Data.Maybe (fromMaybe, isJust)
import           Control.Monad (filterM)
--------------------------------------------------------------------------------
-----RULES-----

main :: IO ()
main = hakyllWith config $ do

    -- Compress CSS
    match ("css/*" 
            .||. "bootstrap/css/*" 
            .||. "highlight/styles/*"
            .||. "fonts/Serif/cmun-serif.css"
            .||. "fonts/Serif Slanted/cmun-serif-slanted.css") $ do
        route   idRoute
        compile compressCssCompiler

    -- Static files
    match ("js/*" 
            .||. "favicon.ico"
            .||. "bootstrap/js/*" 
            .||. "bootstrap/fonts/*" 
            .||. "images/*"
            .||. "images/highlight/*" 
            .||. "highlight/highlight.pack.js"
            .||. "fonts/Serif/*"
            .||. "fonts/Serif-Slanted/*"
            .||. "comments/*"
            .||. "js/MathBox.js/**"
            .||. "posts/**" .&&. (complement postPattern)) $ do
        route idRoute
        compile copyFileCompiler

    match "pages/*.md" $ do
        route   $ gsubRoute "pages/" (const "") `composeRoutes`
                  setExtension "html"
        compile $ myPandoc
            >>= loadAndApplyTemplate "templates/default.html" (mathCtx <> defaultContext)
            >>= relativizeUrls

    match postPattern $ do
        route $ setExtension ".html"
        compile $ myPandoc
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< onlyPublished =<< loadAll postPattern

            let archiveCtx =
                    listField "posts" (postCtx) (return posts)
                    <> constField "title" "Archives"
                    <> mathCtx
                    <> defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx 
                    <> constField "description" ""

            posts <- fmap (take 10) . recentFirst =<< onlyPublished =<< loadAll "posts/*"
            renderRss myFeedConfiguration feedCtx posts

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< onlyPublished =<< loadAll postPattern
            
            let indexCtx =
                    listField "posts" (postCtx) (return posts)
                    <> constField "title" "Home"
                    <> mathCtx
                    <> defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/index_template.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

--------------------------------------------------------------------------------
----- CONTEXTS ------

postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y"
    <> mathCtx
    <> urlstripCtx
    <> defaultContext

-- MathJax
mathCtx :: Context String
mathCtx = field "mathjax" $ \item -> do
    metadata <- getMetadata $ itemIdentifier item
    return $ "<script type=\"text/javascript\" src=\"http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML\"></script>"
    
-- Gets rid of "/index.html" from posts
urlstripCtx :: Context a
urlstripCtx = field "url" $ \item -> do
    route <- getRoute (itemIdentifier item)
    return $ fromMaybe "/" $ 
        fmap (reverse . drop 10 . reverse) route

-- For filtering lists of items to only be published items
onlyPublished :: MonadMetadata m => [Item a] -> m [Item a]
onlyPublished = filterM isPublished where
    isPublished item = do
        pubfield <- getMetadataField (itemIdentifier item) "published"
        return (isJust pubfield)

--------------------------------------------------------------------------------
----- CONFIGS ------

-- RSS feed -- 
myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "Lambda Oinks"
    , feedDescription = "A blog for all things lambda and oinks."
    , feedAuthorName  = "Oinkina"
    , feedAuthorEmail = "lambdaoinks@gmail.com"
    , feedRoot        = "http://oinkina.github.io"
    }

-- Deploy blog with: ./site deploy --
config = defaultConfiguration { deployCommand = "./update.sh" }

myWriterOptions :: WriterOptions
myWriterOptions = defaultHakyllWriterOptions {
                      writerReferenceLinks = True
                    , writerHtml5 = True
                    , writerHighlight = True
                    , writerHTMLMathMethod = MathJax "http://cdn.mathjax.org/mathjax/latest/MathJax.js"
                    }

myPandoc = pandocCompilerWith defaultHakyllReaderOptions myWriterOptions

postPattern = "posts/*/index.md"