module Instructions 
	( Instructions(..)
	, AST(..)
	, module Expression
	, treeExp
	, treeAST
	, treeIns
	,filterI
	, filterE
)
where

import Position
import Expression
import Data.Tree

data Instructions
	= IfL 		Expression 		[Instructions]  Position
	| IfteL		Expression 		[Instructions]  [Instructions]  Position
	| ForL 		Expression 		Expression 		Expression		[Instructions]	Position
	| WhileL 	Expression 		[Instructions]	Position
	| RepeatL 	[Instructions] 	Expression		Position
	| ReadL 	Expression		Position
	| WriteL	Expression 		Position
	| ReturnL 	Expression		Position
	| AsngL 	Expression 		Expression		Position
--	| NewL 		Expression
	| FreeL 	Expression		Position
	| None
	deriving(Show, Eq)

data AST = AST [Instructions] deriving (Eq, Show)

--newtype Nodo = AST | Instructions | Expression 

treeAST :: AST -> Tree String
treeAST (AST is) = Node "AST" (map treeIns is)

treeIns :: Instructions -> Tree String
treeIns (IfL exp is p) 
	= Node ("IF " ++ show p) ((treeExp exp): map treeIns is)
treeIns (IfteL exp ist ise p) 
	= Node ("IF-Then-Else " ++ show p) ((treeExp exp):map treeIns ist ++ map treeIns ise)
treeIns (ForL exp1 exp2 exp3 is p) 
	= Node ("For " ++ show p) ((treeExp exp1):(treeExp exp2):(treeExp exp3):map treeIns is)
treeIns (WhileL exp is p) 
	= Node ("While " ++ show p) ((treeExp exp):map treeIns is)
treeIns (RepeatL is exp p) 
	= Node ("Repeat " ++ show p) ((treeExp exp):map treeIns is)
treeIns (ReadL exp p) 
	= Node ("Read " ++ show p) [treeExp exp]
treeIns (WriteL exp p) 
	= Node ("Write " ++ show p) [treeExp exp]
treeIns (ReturnL exp p) 
	= Node ("Return " ++ show p) [treeExp exp]
treeIns (AsngL exp1 exp2 p) 
	= Node ("Assignation " ++ show p) [treeExp exp1, treeExp exp2]
treeIns (FreeL exp p) 
	= Node ("Free " ++ show p) [treeExp exp]
treeIns None = Node "" []

treeExp :: Expression -> Tree String
treeExp (BoolL b p) = Node ("Bool " ++ show p) [Node (show b) []]
treeExp (IntL i p) = Node ("Int " ++ show p) [Node (show i) []]
treeExp (FloatL f p) = Node ("Float " ++ show p) [Node (show f) []]
treeExp (CharL c p) = Node ("Char " ++ show p) [Node (show c) []]
treeExp (StringL s p) = Node ("String " ++ show p) [Node (show s) []]
treeExp (VoidL p) = Node ("Void " ++ show p) []
treeExp (IdL s p) = Node ("Variable " ++ show p) [Node (show s) []]
treeExp (ExpBin op exp1 exp2 p) 
	= Node ("ExpBin: " ++ show op ++ " " ++ show p) [treeExp exp1, treeExp exp2]
treeExp (ExpUna op exp p) 
	= Node ("ExpUn: " ++ show op ++ " " ++ show p) [treeExp exp]
treeExp (FCall e es p)    -- Era lo que estaba al revez y no se si sea lo mejor poner una variable.
	= Node ("Function " ++ show p) ((treeExp e):map treeExp (reverse es)) 
treeExp (CFCall exp1 exp2 p) 
	= Node ("Function " ++ show p) [treeExp exp1,treeExp exp2] -- No estoy seguro si esta bien
treeExp (AccsA e es p) 
	= Node ("Array " ++ show p) ((treeExp e):map treeExp (reverse es)) -- Era lo que estaba al revez
treeExp (AccsS e es p) 
	= Node ("Accesor " ++ show p) ((treeExp e):map treeExp es)

filterI :: AST -> AST
filterI (AST is) = AST (filter (/= None) is)

filterE :: [Expression] -> [Expression]
filterE le = filter (/= NoneE) le