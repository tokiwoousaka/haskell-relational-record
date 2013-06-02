{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Database.Record.TH (
  recordTypeNameDefault, recordTypeDefault,

  defineHasKeyConstraintInstance,
  defineHasNotNullKeyInstance,
  defineHasPrimaryKeyInstance,
  defineHasPrimaryKeyInstanceDefault,
  defineHasNotNullKeyInstanceDefault,

  derivingEq, derivingShow, derivingRead, derivingData, derivingTypable,

  defineRecordType, defineRecordTypeDefault,

  defineRecordConstructFunction,
  defineRecordDecomposeFunction,

  definePersistableInstance,

  defineRecordWithSqlType,
  defineRecordWithSqlTypeDefault,

  defineRecordWithSqlTypeFromDefined,
  defineRecordWithSqlTypeDefaultFromDefined,

  defineRecord,
  defineRecordDefault,

  deriveNotNullType
  ) where


import Language.Haskell.TH.Name.CamelCase
  (ConName(conName), VarName(varName, VarName),
   conCamelcaseName, varCamelcaseName, varNameWithPrefix,
   toTypeCon, toVarExp)
import Language.Haskell.TH.Lib.Extra (integralE, compileError)
import Language.Haskell.TH
  (Q, mkName, reify, Info(TyConI),
   TypeQ, conT, Con (RecC),
   Dec(DataD), DecQ, dataD, sigD, funD,
   appsE, conE, varE, listE, stringE,
   listP, varP, wildP,
   normalB, recC, clause, cxt,
   varStrictType, strictType, isStrict)
import Language.Haskell.TH.Syntax (VarStrictType)

import Database.Record
  (HasKeyConstraint(keyConstraint), Primary, NotNull,
   Persistable(persistable), PersistableWidth(persistableWidth),
   fromSql, toSql,
   FromSql(recordFromSql), recordFromSql',
   ToSql(recordToSql), recordToSql')

import Database.Record.KeyConstraint
  (specifyKeyConstraint, specifyNotNullValue)
import Database.Record.Persistable
  (persistableRecord, persistableRecordWidth)
import qualified Database.Record.Persistable as Persistable


recordTypeNameDefault :: String -> ConName
recordTypeNameDefault =  conCamelcaseName

recordTypeDefault :: String -> TypeQ
recordTypeDefault =  toTypeCon . recordTypeNameDefault

defineHasKeyConstraintInstance :: TypeQ -> TypeQ -> Int -> Q [Dec]
defineHasKeyConstraintInstance constraint typeCon index =
  [d| instance HasKeyConstraint $constraint $typeCon where
        keyConstraint = specifyKeyConstraint $(integralE index) |]

defineHasNotNullKeyInstance :: TypeQ -> Int -> Q [Dec]
defineHasNotNullKeyInstance =
  defineHasKeyConstraintInstance [t| NotNull |]

defineHasPrimaryKeyInstance :: TypeQ -> Int -> Q [Dec]
defineHasPrimaryKeyInstance =
  defineHasKeyConstraintInstance [t| Primary |]

defineHasPrimaryKeyInstanceDefault :: String  -- ^ Table name
                                   -> Int     -- ^ Primary key index
                                   -> Q [Dec] -- ^ Declaration of primary key constraint
defineHasPrimaryKeyInstanceDefault =
  defineHasPrimaryKeyInstance . recordTypeDefault

defineHasNotNullKeyInstanceDefault :: String  -- ^ Table name
                                   -> Int     -- ^ Not null key index
                                   -> Q [Dec] -- ^ Declaration of not null key constraint
defineHasNotNullKeyInstanceDefault =
  defineHasNotNullKeyInstance . recordTypeDefault

derivingEq   = conCamelcaseName "Eq"
derivingShow = conCamelcaseName "Show"
derivingRead = conCamelcaseName "Read"
derivingData = conCamelcaseName "Data"
derivingTypable = conCamelcaseName "Typable"
derivingEq, derivingShow, derivingRead, derivingData, derivingTypable :: ConName

defineRecordType :: ConName            -- ^ Name of the data type of table record type.
                 -> [(VarName, TypeQ)] -- ^ List of fields in the table. Must be legal, properly cased record fields.
                 -> [ConName]          -- ^ Deriving type class names.
                 -> DecQ               -- ^ The data type record declaration.
defineRecordType typeName' fields derives = do
  let typeName = conName typeName'
  dataD (cxt []) typeName [] [recC typeName (map fld fields)] (map conName derives)
  where
    fld (n, tq) = varStrictType (varName n) (strictType isStrict tq)

columnDefault :: String -> TypeQ -> (VarName, TypeQ)
columnDefault n t = (varCamelcaseName n, t)

defineRecordTypeDefault :: String -> [(String, TypeQ)] -> [ConName] -> DecQ
defineRecordTypeDefault table columns =
  defineRecordType
  (recordTypeNameDefault table)
  [ columnDefault n t | (n, t) <- columns ]


defineRecordConstructFunction :: TypeQ     -- ^ SQL value type.
                              -> VarName   -- ^ Name of record construct function.
                              -> ConName   -- ^ Name of record type.
                              -> Int       -- ^ Count of record fields.
                              -> Q [Dec]   -- ^ Declaration of record construct function from SQL values.
defineRecordConstructFunction sqlValType funName' typeName' width = do
  let funName = varName funName'
      typeName = conName typeName'
      names = map (mkName . ('f':) . show) [1 .. width]
      fromSqlE n = [| fromSql $(varE n) |]
  sig <- sigD funName [t| [$(sqlValType)] -> $(conT typeName) |]
  var <- funD funName
         [ clause
           [listP (map varP names)]
            (normalB . appsE $ conE typeName : map fromSqlE names)
            [],
            clause [wildP]
            (normalB
             [| error
                $(stringE
                  $ "Generated code of 'defineRecordConstructFunction': Fail to pattern match in: "
                  ++ show funName
                  ++ ", count of fields is " ++ show width) |])
            [] ]
  return [sig, var]

defineRecordDecomposeFunction :: TypeQ     -- ^ SQL value type.
                              -> VarName   -- ^ Name of record decompose function.
                              -> TypeQ     -- ^ Name of record type.
                              -> [VarName] -- ^ List of field names of record.
                              -> Q [Dec]   -- ^ Declaration of record construct function from SQL values.
defineRecordDecomposeFunction sqlValType funName' typeCon fields = do
  let funName = varName funName'
      accessors = map toVarExp fields
      recVar = mkName "rec"
  sig <- sigD funName [t| $typeCon -> [$(sqlValType)] |]
  var <- funD funName [ clause [varP recVar]
                        (normalB . listE $ [ [| toSql ($a $(varE recVar)) |] | a <- accessors ])
                        [] ]
  return [sig, var]

definePersistableInstance :: TypeQ   -- ^ SQL value type
                          -> TypeQ   -- ^ Record type
                          -> VarName -- ^ Construct function name
                          -> VarName -- ^ Decompose function name
                          -> Int     -- ^ Record width
                          -> Q [Dec] -- ^ Instance declarations for 'Persistable'
definePersistableInstance sqlType typeCon consFunName' decompFunName' width = do
  [d| instance PersistableWidth $typeCon where
        persistableWidth = persistableRecordWidth $(integralE width)

      instance Persistable $sqlType $typeCon where
        persistable = persistableRecord
                      persistableWidth
                      $(toVarExp consFunName')
                      $(toVarExp decompFunName')

      instance FromSql $sqlType $typeCon where
        recordFromSql = recordFromSql'

      instance ToSql $sqlType $typeCon where
        recordToSql = recordToSql'
    |]

defineRecordWithSqlType :: TypeQ              -- ^ SQL value type
                        -> (VarName, VarName) -- ^ Constructor function name and decompose function name
                        -> ConName            -- ^ Record type name
                        -> [(VarName, TypeQ)] -- ^ Column schema
                        -> Q [Dec]            -- ^ Result declarations
defineRecordWithSqlType
  sqlValueType
  (cF, dF) tyC
  columns = do
  let width = length columns
      typeCon = toTypeCon tyC
  fromSQL  <- defineRecordConstructFunction sqlValueType cF tyC width
  toSQL    <- defineRecordDecomposeFunction sqlValueType dF typeCon (map fst columns)
  instSQL  <- definePersistableInstance sqlValueType typeCon cF dF width
  return $ fromSQL ++ toSQL ++ instSQL

fromSqlNameDefault :: String -> VarName
fromSqlNameDefault =  (`varNameWithPrefix` "fromSqlOf")

toSqlNameDefault :: String -> VarName
toSqlNameDefault =  (`varNameWithPrefix` "toSqlOf")

defineRecordWithSqlTypeDefault :: TypeQ             -- ^ SQL value type
                               -> String            -- ^ Table name of database
                               -> [(String, TypeQ)] -- ^ Column names and types
                               -> Q [Dec]           -- ^ Result declarations
defineRecordWithSqlTypeDefault sqlValueType table columns = do
  defineRecordWithSqlType
    sqlValueType
    (fromSqlNameDefault table, toSqlNameDefault table)
    (recordTypeNameDefault table)
    [ columnDefault n t | (n, t) <- columns ]

recordInfo :: Info -> Maybe [VarStrictType]
recordInfo =  d  where
  d (TyConI (DataD _cxt _n _bs [RecC _dn vs] _ds)) = Just vs
  d _                                              = Nothing

defineRecordWithSqlTypeFromDefined :: TypeQ              -- ^ SQL value type
                                   -> (VarName, VarName) -- ^ Constructor function name and decompose function name
                                   -> ConName            -- ^ Record type name
                                   -> Q [Dec]            -- ^ Result declarations
defineRecordWithSqlTypeFromDefined sqlValueType fnames recTypeName' = do
  let recTypeName = conName recTypeName'
  recInfo <- reify recTypeName
  case recordInfo recInfo of
    Nothing -> compileError $ "Defined record type not found: " ++ show recTypeName
    Just vs -> defineRecordWithSqlType sqlValueType fnames recTypeName'
               [ (VarName n, return ty) | (n, _s, ty)  <- vs ]

defineRecordWithSqlTypeDefaultFromDefined :: TypeQ   -- ^ SQL value type
                                          -> String  -- ^ Table name of database
                                          -> Q [Dec] -- ^ Result declarations
defineRecordWithSqlTypeDefaultFromDefined sqlValueType table =
  defineRecordWithSqlTypeFromDefined sqlValueType
  (fromSqlNameDefault table, toSqlNameDefault table)
  (recordTypeNameDefault table)


defineRecord :: TypeQ              -- ^ SQL value type
             -> (VarName, VarName) -- ^ Constructor function name and decompose function name
             -> ConName            -- ^ Record type name
             -> [(VarName, TypeQ)] -- ^ Column schema
             -> [ConName]          -- ^ Record derivings
             -> Q [Dec]            -- ^ Result declarations
defineRecord
  sqlValueType
  fnames tyC
  columns drvs = do

  typ     <- defineRecordType tyC columns drvs
  withSql <- defineRecordWithSqlType sqlValueType fnames tyC columns
  return $ typ : withSql

defineRecordDefault :: TypeQ             -- ^ SQL value type
                    -> String            -- ^ Table name
                    -> [(String, TypeQ)] -- ^ Column names and types
                    -> [ConName]         -- ^ Record derivings
                    -> Q [Dec]           -- ^ Result declarations
defineRecordDefault sqlValueType table columns derives = do
  typ     <- defineRecordTypeDefault table columns derives
  withSql <- defineRecordWithSqlTypeDefault sqlValueType table columns
  return $ typ : withSql


deriveNotNullType :: TypeQ -> Q [Dec]
deriveNotNullType typeCon =
  [d| instance PersistableWidth $typeCon where
        persistableWidth = Persistable.valueWidth

      instance HasKeyConstraint NotNull $typeCon where
        keyConstraint = specifyNotNullValue
    |]
