module Types exposing (Flags, Model(..), Msg(..), Submodel(..), ValidModel)

import AgentHistory.Types
import BigInt exposing (BigInt)
import Browser
import Browser.Navigation
import CommonTypes exposing (UserInfo)
import Create.Types
import Eth.Sentry.Tx as TxSentry exposing (TxSentry)
import Eth.Sentry.Wallet as WalletSentry exposing (WalletSentry)
import Eth.Types exposing (Address)
import EthHelpers exposing (EthNode)
import Json.Decode
import Marketplace.Types
import Routing
import Time
import Trade.Types
import TradeCache.Types as TradeCache exposing (TradeCache)
import Url exposing (Url)


type alias Flags =
    { networkId : Int
    , width : Int
    , height : Int
    }


type Model
    = Running ValidModel
    | Failed String


type alias ValidModel =
    { key : Browser.Navigation.Key
    , time : Time.Posix
    , node : EthNode
    , txSentry : TxSentry Msg
    , userAddress : Maybe Address
    , userInfo : Maybe UserInfo
    , tradeCache : TradeCache
    , submodel : Submodel
    }


type Submodel
    = BetaLandingPage
    | CreateModel Create.Types.Model
    | TradeModel Trade.Types.Model
    | MarketplaceModel Marketplace.Types.Model
    | AgentHistoryModel AgentHistory.Types.Model


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | GotoRoute Routing.Route
    | Tick Time.Posix
    | WalletStatus WalletSentry
    | TxSentryMsg TxSentry.Msg
    | UserPubkeySet Json.Decode.Value
    | TradeCacheMsg TradeCache.Msg
    | CreateMsg Create.Types.Msg
    | TradeMsg Trade.Types.Msg
    | MarketplaceMsg Marketplace.Types.Msg
    | AgentHistoryMsg AgentHistory.Types.Msg
    | Fail String
    | NoOp
