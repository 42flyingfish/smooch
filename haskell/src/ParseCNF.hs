{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}

module ParseCNF where

import Kiss
import Text.ParserCombinators.Parsec
import Data.List hiding (lines)
import Data.Maybe
import qualified Data.Text as T 
import Control.Monad.Trans.Either 

getKissData :: String -> EitherT T.Text IO KissData
getKissData file = 
    case parse parseCNFLines "KiSS CNF error: " file of
      Right ls -> return $ linesToScript ls
      Left e  -> EitherT $ return $ Left $ T.pack $ show e

getKissCels :: String -> EitherT T.Text IO [KissCell]
getKissCels file = 
    case parse parseCNFLines "KiSS cel error: " file of
      Right ls -> return $ linesToCells ls
      Left e  -> EitherT $ return $ Left $ T.pack $ show e

getKissPalette :: KissData -> EitherT T.Text IO String
getKissPalette file = 
  case kPalettes file of
    (x:_) -> return x
    []     -> EitherT $ return $ Left "no palette found"

-- Converting CNF lines to useable KiSS data
linesToScript :: [CNFLine] -> KissData
linesToScript xs = 
    KissData memory border palettes windowSize objects 
    where -- memory and border are optional 
          memory   = fromMaybe 0 (listToMaybe [ a | CNFMemory a <- xs ])
          border   = fromMaybe 0 (listToMaybe [ a | CNFBorder a <- xs ])
          -- at least one palette must be specified
          palettes = [ a | CNFPalette a <- xs ]
          -- window is (600, 480) by default
          windowSize = fromMaybe (600, 480) (listToMaybe [ a | CNFWindowSize a <- xs ])
          -- turn object #, cell, set positions to objects 
          positions = [ a | CNFSetPos a <- xs ]
          objects = linesToObjects [ a | CNFCell a <- xs ] positions

linesToObjects :: [(Int, KissCell)] -> [KissSetPos] -> [KissObject]
linesToObjects xs ys = 
    map (\((x,y),z) -> KissObject x y z) (zipIt cells positions)
    where cells = map (\x -> combineCells (fst x) xs) xs
          positions = zip (sort $ map fst xs) (cellPositions ys)

zipIt :: [(Int, [KissCell])] -> [(Int,[SetPos])] -> [((Int, [KissCell]), [SetPos])]
zipIt cells positions = [ (cell, snd pos) | cell <- cells, pos <- positions, fst cell == fst pos]

-- A CNF's [KissSetPos] is 10 lists of SetPos each `#cells` long.
-- This turns them into `#cells` lists of 10 SetPos.
cellPositions :: [KissSetPos] -> [[SetPos]]
cellPositions xs = transpose $ map (\(KissSetPos pal pos) -> pos) xs

combineCells :: Int -> [(Int, KissCell)] -> (Int, [KissCell])
combineCells n xs = (n, map snd (filter (\x -> fst x == n) xs))

linesToCells :: [CNFLine] -> [KissCell]
linesToCells xs = [ snd a | CNFCell a <- xs ]
 
-- KiSS Parser Combinators

-- Parses the lines describing cells and objects.
parseCellLine :: Parser CNFLine
parseCellLine = do
    char '#'
    num <- many digit
    cell <- parseCell
    optional parseComment
    return $ CNFCell (read num, cell)

parseCell :: Parser KissCell
parseCell = do
    fix <- option 0 parseFix
    skipMany1 space
    file <- many1 (noneOf ". ")
    string ".cel" <?> "cel file extenstion"
    skipMany1 space
    palette <- option 0 (try parseCellPalette)
    skipMany space
    optional (char ':')
    skipMany space
    sets <- option [] parseSets
    skipMany space
    transp <- option 0 (try parseTransp)
    return $ KissCell fix file palette sets transp

parseCellPalette :: Parser Int
parseCellPalette = do
    char '*'
    num <- many1 digit
    return $ read num

parseFix :: Parser Int
parseFix = do
    char '.'
    num <- many digit
    return $ read num

-- This parses all the list of sets the cell will be displayed in
parseSets :: Parser [Int]
parseSets = many1 parseSet

parseSet :: Parser Int
parseSet = do
    num <- digit
    skipMany space
    return $ read [num]

parseComment :: Parser String
parseComment = do    
    char ';'
    many (noneOf "\r\n")

parseTransp :: Parser Int
parseTransp = do
    string ";%t"
    num <- many digit
    return $ read num

parseMemory :: Parser CNFLine
parseMemory = do
    char '='
    num <- many digit
    return $ CNFMemory (read num)

parseWindowSize :: Parser CNFLine
parseWindowSize = do
    char '('
    width <- many digit
    char ','
    height <- many digit
    char ')'
    return $ CNFWindowSize (read width, read height)

parsePalette :: Parser CNFLine
parsePalette = do
    char '%'
    filename <- many (choice [letter, digit, char '_', char '-', char '.'])
    return $ CNFPalette filename

parseBorder :: Parser CNFLine
parseBorder = do
    char '['
    num <- many digit
    return $ CNFBorder (read num)

-- The following four functions parse the cel positions for each set of cells.
parseSetPos :: Parser CNFLine
parseSetPos = do
    char '$'
    paletteGroup <- digit
    positions <- many parsePosition
    return $ CNFSetPos (KissSetPos (read [paletteGroup]) positions)

parsePosition :: Parser SetPos
parsePosition = do
    spaces
    position <- parsePos <|> parseNoPos <?> "position"
    spaces
    return position

parsePos :: Parser SetPos
parsePos = do
    xsign <- option '0' (char '-')
    xpos <- many1 digit
    char ','
    ysign <- option '0' (char '-')
    ypos <- many1 digit
    return $ Position (read $ xsign : xpos) (read $ ysign : ypos)

parseNoPos :: Parser SetPos
parseNoPos = do
    char '*'
    return NoPosition

data CNFLine = CNFMemory Int
             | CNFBorder Int
             | CNFPalette String
             | CNFWindowSize (Int, Int)
             | CNFCell (Int, KissCell)
             | CNFSetPos KissSetPos
             | CNFComment String
    deriving (Eq, Show)

-- Parse the CNF one "line" (including mult-line set descriptions) at a time
parseCNFLines :: Parser [CNFLine]
parseCNFLines = do
    ls <- many parseCNFLine
    eof
    return ls

parseCNFLine :: Parser CNFLine
parseCNFLine = do
    line <- choice [parseCellLine, 
                    parseSetPos,
                    parseMemory, parsePalette, 
                    parseBorder, parseWindowSize, 
                    parseCNFComment]
    spaces
    return line

parseCNFComment :: Parser CNFLine
parseCNFComment = do
    char ';'
    comment <- many (noneOf "\r\n")
    return $ CNFComment comment
