{

{-# OPTIONS_GHC -w #-}

-------------- Lexer para el lenguaje de programación Pandora -----------------
module Lexer
    ( fPrint
    , scanner
    , Alex(..)
    , Token(..)
    , Lexeme(..)
    , Error(..)
    , module Error
    ) where

import Error
import Control.Monad
import Data.Sequence (Seq, empty, (|>))
import System.IO (readFile, hPutStrLn, stderr, stdout)
import System.Environment (getArgs)
}

------------------------- Expresiones regulares -------------------------------

%wrapper "monadUserState"
$backslash  = [\\abfnrtv]
$digit      = 0-9
$lower      = [a-z _]
$upper      = [A-Z]
@exp        = [e][\-\+]? $digit+
@string     = \".*\"
@badString  = \".*
@ident      = $lower($upper|$lower|$digit)*
@int        = $digit+
@float      = $digit+(\.$digit+) @exp?
@char       = \'($printable # [\\'] | \\' | \\$backslash)\'

--------------------------- Tokens del lenguaje ------------------------------
tokens :- 

    --Whitespaces
    <0> $white+ ;

    --Comment
    <0> "--".*  ;
    --Nested Comment
    <0> "-*"            { enterNewComment `andBegin` n }
    <n> "-*"            { embedComment }
    <n> "*-"            { unembedComment }
    <n> .               ;
    <n> \n              { skip }
    -- brackets 
    <0> "["             { tok' TokenBracketOpen }
    <0> "]"             { tok' TokenBracketClose }
    <0> "("             { tok' TokenParenOpen }
    <0> ")"             { tok' TokenParenClose }
    -- separators
    <0> ","             { tok' TokenComma }
    <0> ";"             { tok' TokenSemicolon }
    -- access to fields
    <0> "."             { tok' TokenPoint }
    -- type declarations
    <0> ":"             { tok' TokenColon }
    -- instructions
    <0> "if"            { tok' TokenIf }
    <0> "then"          { tok' TokenThen }
    <0> "else"          { tok' TokenElse }
    <0> "while"         { tok' TokenWhile }
    <0> "for"           { tok' TokenFor }
    <0> "from"          { tok' TokenFrom }
    <0> "to"            { tok' TokenTo }
    <0> "with"          { tok' TokenWith }
    <0> "do"            { tok' TokenDo }
    <0> "like"          { tok' TokenLike }
    <0> "has"           { tok' TokenHas }
    <0> "return"        { tok' TokenReturn }
    <0> "new"           { tok' TokenNew }
    <0> "begin"         { tok' TokenBegin }
    <0> "end"           { tok' TokenEnd }
    <0> "func"          { tok' TokenFunc }
    <0> "proc"          { tok' TokenProc }
    <0> "free"          { tok' TokenFree }
    <0> "repeat"        { tok' TokenRepeat }
    <0> "until"         { tok' TokenUntil }
    <0> "read"          { tok' TokenRead }
    <0> "write"         { tok' TokenWrite }
    <0> "of"            { tok' TokenOf }
    <0> "intToString"   { tok' TokenITS }
    <0> "floatToString" { tok' TokenFTS }
    <0> "intToFloat"    { tok' TokenITF }
    -- types
    <0> "int"           { tok' TokenIntT }
    <0> "float"         { tok' TokenFloatT }
    <0> "char"          { tok' TokenCharT }
    <0> "bool"          { tok' TokenBoolT }
    <0> "array"         { tok' TokenArray }
    <0> "string"        { tok' TokenStringT }
    <0> "struct"        { tok' TokenStruct }
    <0> "union"         { tok' TokenUnion }
    <0> @int            { tok lexInt }
    <0> @float          { tok lexFloat }
    <0> @char           { tok (TokenChar  . read) }
    <0> @string         { tok (TokenString . read) }
    <0> @badString      { tok' TokenStringError  }
    -- boolean constants
    <0> "true"          { tok' TokenTrue }
    <0> "false"         { tok' TokenFalse }
    -- null value
    <0> "null"          { tok' TokenNull }
    -- reference id
    <0> "var"           { tok' TokenVar }
    -- binary operators
    <0> "="             { tok' TokenAssign }
    <0> "=="            { tok' TokenEq }
    <0> "/="            { tok' TokenIneq }
    <0> "+"             { tok' TokenPlus }
    <0> "-"             { tok' TokenMinus }
    <0> "*"             { tok' TokenAsterisk }
    <0> "div"           { tok' TokenDivInt }
    <0> "/"             { tok' TokenDivFloat }
    <0> "mod"           { tok' TokenMod }
    <0> ">"             { tok' TokenGT }
    <0> ">="            { tok' TokenGE }
    <0> "<"             { tok' TokenLT }
    <0> "<="            { tok' TokenLE }
    <0> "^"             { tok' TokenCircum }
    <0> "and"           { tok' TokenAnd }
    <0> "or"            { tok' TokenOr }
    -- unary operators
    <0> "not"           { tok' TokenNot }
    <0> "->"            { tok' TokenArrow }
    
    -- Identifier
    <0> @ident          { tok TokenIdent . id }

    <0>.            { tok (TokenError . head)}

{

----------------------------- Lógica del lexer --------------------------------

data AlexUserState = 
    AlexUST 
        { errors            :: Seq Error
        , lexerCommentDepth :: Int 
        }

alexInitUserState :: AlexUserState
alexInitUserState = 
    AlexUST
        { errors = empty
        , lexerCommentDepth = 0
        } 

-- control de profundidad para comentarios multilínea
getLexerCommentDepth :: Alex Int
getLexerCommentDepth = 
    Alex $ \s@AlexState{alex_ust=ust} -> Right (s, lexerCommentDepth ust)

setLexerCommentDepth :: Int -> Alex ()
setLexerCommentDepth ss = 
    Alex $ \s -> Right (s{alex_ust=(alex_ust s){lexerCommentDepth=ss}}, ())

enterNewComment input len =
    do setLexerCommentDepth 1
       skip input len

embedComment input len =
    do cd <- getLexerCommentDepth
       setLexerCommentDepth (cd + 1)
       skip input len

unembedComment input len =
    do cd <- getLexerCommentDepth
       setLexerCommentDepth (cd - 1)
       when (cd == 1) (alexSetStartCode state_initial)
       skip input len

addLError :: Position -> LexerError -> Alex ()
addLError p e = Alex $ \s -> Right (s{alex_ust=(alex_ust s){errors=errors (alex_ust s) |> (LError p e)}}, ())

-- obtiene la posición del token
alexGetPosition :: Alex Position
alexGetPosition = alexGetInput >>= \(p,_,_,_) -> return $ toPosition p

toPosition :: AlexPosn -> Position
toPosition (AlexPn _ r c) = Position (r, c)

-- token fin de archivo
alexEOF :: Alex (Lexeme Token )
alexEOF = liftM (Lexeme TokenEOF ) alexGetPosition

-- verifica overflow de enteros
lexInt :: String -> Token
lexInt s
  | n < (-2^31)     =  TokenIntError s 
  | n > (2^31) - 1  =  TokenIntError s  
  | otherwise       =  TokenInt      n
  where n = (read s :: (Num a, Read a) => a)

-- verifica overflow y underflow de punto flotante
lexFloat :: String -> Token
lexFloat s
  | n < 1.0e-38    =  TokenFloatErrorU s 
  | n > 1.0e38     =  TokenFloatErrorO s
  | otherwise      =  TokenFloat      n 
  where n = (read s :: (Num a, Read a) => a)

-- construye lexemas 
tok :: (String -> Token) -> AlexAction ( Lexeme Token )
tok f (p,_,_,s) i = return $ Lexeme (f $ take i s) (toPosition p)

tok' :: Token -> AlexAction (Lexeme Token)
tok' = tok . const

-- estado inicial
state_initial :: Int
state_initial = 0

-- error del lexer
lexError str = do
    (pos, _, _, input) <- alexGetInput
    alexError $ showPosn pos ++ ": " ++ str ++
        (if (not (null input))
            then " before " ++ show (head input)
            else " at end of file")
showPosn (AlexPn _ line col) = show line ++ ':': show col

-- scanner de tokens
scanner str = runAlex str $ do
    let loop = do
        lex@(Lexeme tok _) <- alexMonadScan
        if tok == TokenEOF
            then do f1 <- getLexerCommentDepth
                    if (f1 == 0)
                        then return [lex]
                        else return [Lexeme TokenBadComment (Position (0,0))]
            else do
                lexs <- loop
                return (lex:lexs)
    loop


-- imprime la informacion del token en la salida correspondiente
fPrint:: Lexeme Token -> IO()
fPrint t = if (isTokenError t) then hPutStrLn stderr (show t)
                else hPutStrLn stdout (show t)


}