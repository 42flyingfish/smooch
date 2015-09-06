{-# LANGUAGE OverloadedStrings #-}

module UploadSpec where

import Test.Hspec
import Upload
import Control.Monad.Trans.Either
import Network.Wai.Parse
import System.Directory
import qualified Data.ByteString.Lazy as BS

{--
shouldSucceed :: EitherT T.Text a -> a -> ??
shouldSucceed m r = 
  if runEitherT m == Right ()
    then True
    else False

shouldSucceedWith :: EitherT T.Text a -> a -> Bool???
shouldSucceedWith m r =
  if runEitherT m == Right r 
    then True  
    else False 

shouldFailWith :: EitherT T.Text a  -> T.Text -> Bool???
shouldFailWith m r = 
  if runEitherT m == Left r 
    then True
    else False
--}

spec = do 
  describe "tryIO" $ do 
    it "returns a Right () if the action completed" $
      runEitherT (tryIO $ return ()) `shouldReturn`
        Right ()
    it "returns a Left with a Text error message if not" $
      runEitherT (tryIO $ readFile "potato" >> return ()) `shouldReturn`
        Left "potato: openFile: does not exist (No such file or directory)"
  describe "getFile" $ 
    it "gets the files from a request" $
      runEitherT (getFile [("filename", FileInfo "filename" "filetype" "content")]) `shouldReturn`
        Right ("filename", "content")
  describe "getRelDir" $ do
    it "gets the path of a directory for the set, relative to static directory" $
      runEitherT (getRelDir [("file.lzh", FileInfo "file.lzh" "lzh" "content")]) `shouldReturn`
        Right "sets/file" 
    it "returns an error message if the list of files is empty" $
      runEitherT (getRelDir []) `shouldReturn` Left "Please upload exactly one file."
  describe "getCNF" $ do
    it "returns the contents of the first CNF file it finds" $
      runEitherT (getCNF "tests/samples") `shouldReturn` Right "okay\n"
    it "gives an error if no CNF is found" $
      runEitherT (getCNF "./") `shouldReturn` Left "No configuration file found."
  describe "processSet" $ 
    it "does a tooooooon of shit, fuck" $ 
      pendingWith "fuuuuuuuuuuuuuuuck"

{--
  describe "uploadSet" $ do
    after_ $  
      removeFile "tests/samples/sets/test.lzh" 
    it "can take a test file and write it to the 'sets' directory" $ 
        do
          f <- BS.readFile "tests/samples/test.lzh"
          r <- runEitherT (uploadSet [("", FileInfo "test.lzh" "" f)] "tests/samples")
          return $ doesFileExist "tests/samples/sets/test.lzh"
        `shouldReturn` (return True :: IO Bool)--}
