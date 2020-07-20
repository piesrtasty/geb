pragma solidity ^0.6.7;

import "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";

import {CDPEngine} from "../CDPEngine.sol";
import {EnglishCollateralAuctionHouse, FixedDiscountCollateralAuctionHouse} from "../CollateralAuctionHouse.sol";
import {OracleRelayer} from "../OracleRelayer.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract Guy {
    EnglishCollateralAuctionHouse englishCollateralAuctionHouse;
    FixedDiscountCollateralAuctionHouse fixedDiscountCollateralAuctionHouse;

    constructor(
      EnglishCollateralAuctionHouse englishCollateralAuctionHouse_,
      FixedDiscountCollateralAuctionHouse fixedDiscountCollateralAuctionHouse_
    ) public {
        englishCollateralAuctionHouse = englishCollateralAuctionHouse_;
        fixedDiscountCollateralAuctionHouse = fixedDiscountCollateralAuctionHouse_;
    }
    function approveCDPModification(bytes32 auctionType, address cdp) public {
        address cdpEngine = (auctionType == "english") ?
          address(englishCollateralAuctionHouse.cdpEngine()) : address(fixedDiscountCollateralAuctionHouse.cdpEngine());
        CDPEngine(cdpEngine).approveCDPModification(cdp);
    }
    function increaseBidSize(uint id, uint amountToBuy, uint rad) public {
        englishCollateralAuctionHouse.increaseBidSize(id, amountToBuy, rad);
    }
    function buyCollateral(uint id, uint amountToBuy, uint wad) public {
        fixedDiscountCollateralAuctionHouse.buyCollateral(id, amountToBuy, wad);
    }
    function decreaseSoldAmount(uint id, uint amountToBuy, uint bid) public {
        englishCollateralAuctionHouse.decreaseSoldAmount(id, amountToBuy, bid);
    }
    function settleAuction(uint id) public {
        englishCollateralAuctionHouse.settleAuction(id);
    }
    function try_increaseBidSize(uint id, uint amountToBuy, uint rad)
        public returns (bool ok)
    {
        string memory sig = "increaseBidSize(uint256,uint256,uint256)";
        (ok,) = address(englishCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id, amountToBuy, rad));
    }
    function try_buyCollateral(uint id, uint amountToBuy, uint wad)
        public returns (bool ok)
    {
        string memory sig = "buyCollateral(uint256,uint256,uint256)";
        (ok,) = address(fixedDiscountCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id, amountToBuy, wad));
    }
    function try_decreaseSoldAmount(uint id, uint amountToBuy, uint bid)
        public returns (bool ok)
    {
        string memory sig = "decreaseSoldAmount(uint256,uint256,uint256)";
        (ok,) = address(englishCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id, amountToBuy, bid));
    }
    function try_settleAuction(uint id)
        public returns (bool ok)
    {
        string memory sig = "settleAuction(uint256)";
        (ok,) = address(englishCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id));
    }
    function try_restartAuction(uint id)
        public returns (bool ok)
    {
        string memory sig = "restartAuction(uint256)";
        (ok,) = address(englishCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id));
    }
    function try_english_terminateAuctionPrematurely(uint id)
        public returns (bool ok)
    {
        string memory sig = "terminateAuctionPrematurely(uint256)";
        (ok,) = address(englishCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id));
    }
    function try_fixedDiscount_terminateAuctionPrematurely(uint id)
        public returns (bool ok)
    {
        string memory sig = "terminateAuctionPrematurely(uint256)";
        (ok,) = address(fixedDiscountCollateralAuctionHouse).call(abi.encodeWithSignature(sig, id));
    }
}


contract Gal {}

contract CDPEngine_ is CDPEngine {
    function mint(address usr, uint wad) public {
        coinBalance[usr] += wad;
    }
    function coin_balance(address usr) public view returns (uint) {
        return coinBalance[usr];
    }
    bytes32 collateralType;
    function set_collateral_type(bytes32 collateralType_) public {
        collateralType = collateralType_;
    }
    function token_collateral_balance(address usr) public view returns (uint) {
        return tokenCollateral[collateralType][usr];
    }
}

contract Feed {
    bytes32 public priceFeedValue;
    bool public hasValidValue;
    constructor(bytes32 initPrice, bool initHas) public {
        priceFeedValue = initPrice;
        hasValidValue = initHas;
    }
    function set_val(bytes32 newPrice) external {
        priceFeedValue = newPrice;
    }
    function set_has(bool newHas) external {
        hasValidValue = newHas;
    }
    function getResultWithValidity() external returns (bytes32, bool) {
        return (priceFeedValue, hasValidValue);
    }
}

contract EnglishCollateralAuctionHouseTest is DSTest {
    Hevm hevm;

    CDPEngine_ cdpEngine;
    EnglishCollateralAuctionHouse collateralAuctionHouse;
    OracleRelayer oracleRelayer;
    Feed    feed;

    address ali;
    address bob;
    address auctionIncomeRecipient;
    address cdpAuctioned = address(0xacab);

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        cdpEngine = new CDPEngine_();

        cdpEngine.initializeCollateralType("collateralType");
        cdpEngine.set_collateral_type("collateralType");

        collateralAuctionHouse = new EnglishCollateralAuctionHouse(address(cdpEngine), "collateralType");

        oracleRelayer = new OracleRelayer(address(cdpEngine));
        collateralAuctionHouse.modifyParameters("oracleRelayer", address(oracleRelayer));

        feed = new Feed(bytes32(uint256(0)), true);
        collateralAuctionHouse.modifyParameters("orcl", address(feed));

        ali = address(new Guy(collateralAuctionHouse, FixedDiscountCollateralAuctionHouse(address(0))));
        bob = address(new Guy(collateralAuctionHouse, FixedDiscountCollateralAuctionHouse(address(0))));
        auctionIncomeRecipient = address(new Gal());

        Guy(ali).approveCDPModification("english", address(collateralAuctionHouse));
        Guy(bob).approveCDPModification("english", address(collateralAuctionHouse));
        cdpEngine.approveCDPModification(address(collateralAuctionHouse));

        cdpEngine.modifyCollateralBalance("collateralType", address(this), 1000 ether);
        cdpEngine.mint(ali, 200 ether);
        cdpEngine.mint(bob, 200 ether);
    }
    function test_startAuction() public {
        collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                            , amountToRaise: 50 ether
                                            , forgoneCollateralReceiver: cdpAuctioned
                                            , auctionIncomeRecipient: auctionIncomeRecipient
                                            , initialBid: 0
                                            });
    }
    function testFail_increaseBidSize_empty() public {
        // can't increase bid size on non-existent
        collateralAuctionHouse.increaseBidSize(42, 0, 0);
    }
    function test_increase_bid_decrease_sold_same_bidder() public {
       uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                     , amountToRaise: 200 ether
                                                     , forgoneCollateralReceiver: cdpAuctioned
                                                     , auctionIncomeRecipient: auctionIncomeRecipient
                                                     , initialBid: 0
                                                     });

        assertEq(cdpEngine.coin_balance(ali), 200 ether);
        Guy(ali).increaseBidSize(id, 100 ether, 190 ether);
        assertEq(cdpEngine.coin_balance(ali), 10 ether);
        Guy(ali).increaseBidSize(id, 100 ether, 200 ether);
        assertEq(cdpEngine.coin_balance(ali), 0);
        Guy(ali).decreaseSoldAmount(id, 80 ether, 200 ether);
    }
    function test_increase_bid() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });

        Guy(ali).increaseBidSize(id, 100 ether, 1 ether);
        // initialBid taken from bidder
        assertEq(cdpEngine.coin_balance(ali),   199 ether);
        // auctionIncomeRecipient receives payment
        assertEq(cdpEngine.coin_balance(auctionIncomeRecipient), 1 ether);

        Guy(bob).increaseBidSize(id, 100 ether, 2 ether);
        // initialBid taken from bidder
        assertEq(cdpEngine.coin_balance(bob), 198 ether);
        // prev bidder refunded
        assertEq(cdpEngine.coin_balance(ali), 200 ether);
        // auctionIncomeRecipient receives excess
        assertEq(cdpEngine.coin_balance(auctionIncomeRecipient), 2 ether);

        hevm.warp(now + 5 hours);
        Guy(bob).settleAuction(id);
        // bob gets the winnings
        assertEq(cdpEngine.token_collateral_balance(bob), 100 ether);
    }
    function test_increase_bid_size_later() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        hevm.warp(now + 5 hours);

        Guy(ali).increaseBidSize(id, 100 ether, 1 ether);
        // initialBid taken from bidder
        assertEq(cdpEngine.coin_balance(ali), 199 ether);
        // auctionIncomeRecipient receives payment
        assertEq(cdpEngine.coin_balance(auctionIncomeRecipient),   1 ether);
    }
    function test_increase_bid_size_nonzero_bid_to_market_ratio() public {
        cdpEngine.mint(ali, 200 * 10**45 - 200 ether);
        collateralAuctionHouse.modifyParameters("bidToMarketPriceRatio", 5 * 10**26); // one half
        feed.set_val(bytes32(uint256(200 ether)));
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 150 * 10**45
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        Guy(ali).increaseBidSize(id, 1 ether, 100 * 10**45);
    }
    function testFail_increase_bid_size_nonzero_bid_to_market_ratio() public {
        cdpEngine.mint(ali, 200 * 10**45 - 200 ether);
        collateralAuctionHouse.modifyParameters("bidToMarketPriceRatio", 5 * 10**26); // one half
        feed.set_val(bytes32(uint256(200 ether)));
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 150 * 10**45
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        Guy(ali).increaseBidSize(id, 1 ether, 100 * 10**45 - 1);
    }
    function test_increase_bid_size_nonzero_bid_to_market_ratio_nonzero_redemptionPrice() public {
        cdpEngine.mint(ali, 200 * 10**45 - 200 ether);
        collateralAuctionHouse.modifyParameters("bidToMarketPriceRatio", 5 * 10**26); // one half
        oracleRelayer.modifyParameters("redemptionPrice", 2 * 10**27); // 2 REF per RAI
        feed.set_val(bytes32(uint256(200 ether)));
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 75 * 10**45
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        Guy(ali).increaseBidSize(id, 1 ether, 50 * 10**45);
    }
    function testFail_increase_bid_size_nonzero_bid_to_market_ratio_nonzero_redemptionPrice() public {
        cdpEngine.mint(ali, 200 * 10**45 - 200 ether);
        collateralAuctionHouse.modifyParameters("bidToMarketPriceRatio", 5 * 10**26); // one half
        oracleRelayer.modifyParameters("redemptionPrice", 2 * 10**27); // 2 REF per RAI
        feed.set_val(bytes32(uint256(200 ether)));
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 75 * 10**45
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        Guy(ali).increaseBidSize(id, 1 ether, 50 * 10**45 - 1);
    }
    function test_decrease_sold() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        Guy(ali).increaseBidSize(id, 100 ether,  1 ether);
        Guy(bob).increaseBidSize(id, 100 ether, 50 ether);

        Guy(ali).decreaseSoldAmount(id,  95 ether, 50 ether);

        assertEq(cdpEngine.token_collateral_balance(address(0xacab)), 5 ether);
        assertEq(cdpEngine.coin_balance(ali),  150 ether);
        assertEq(cdpEngine.coin_balance(bob),  200 ether);
    }
    function test_beg() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        assertTrue( Guy(ali).try_increaseBidSize(id, 100 ether, 1.00 ether));
        assertTrue(!Guy(bob).try_increaseBidSize(id, 100 ether, 1.01 ether));
        // high bidder is subject to bid increase
        assertTrue(!Guy(ali).try_increaseBidSize(id, 100 ether, 1.01 ether));
        assertTrue( Guy(bob).try_increaseBidSize(id, 100 ether, 1.07 ether));

        // can bid by less than bid increase
        assertTrue( Guy(ali).try_increaseBidSize(id, 100 ether, 49 ether));
        assertTrue( Guy(bob).try_increaseBidSize(id, 100 ether, 50 ether));

        assertTrue(!Guy(ali).try_decreaseSoldAmount(id, 100 ether, 50 ether));
        assertTrue(!Guy(ali).try_decreaseSoldAmount(id,  99 ether, 50 ether));
        assertTrue( Guy(ali).try_decreaseSoldAmount(id,  95 ether, 50 ether));
    }
    function test_settle_auction() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });

        // only after bid expiry
        Guy(ali).increaseBidSize(id, 100 ether, 1 ether);
        assertTrue(!Guy(bob).try_settleAuction(id));
        hevm.warp(now + 4.1 hours);
        assertTrue( Guy(bob).try_settleAuction(id));

        uint ie = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });

        // or after end
        hevm.warp(now + 44 hours);
        Guy(ali).increaseBidSize(ie, 100 ether, 1 ether);
        assertTrue(!Guy(bob).try_settleAuction(ie));
        hevm.warp(now + 1 days);
        assertTrue( Guy(bob).try_settleAuction(ie));
    }
    function test_restart_auction() public {
        // start an auction
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        // check no restart
        assertTrue(!Guy(ali).try_restartAuction(id));
        // run past the end
        hevm.warp(now + 2 weeks);
        // check not biddable
        assertTrue(!Guy(ali).try_increaseBidSize(id, 100 ether, 1 ether));
        assertTrue( Guy(ali).try_restartAuction(id));
        // check biddable
        assertTrue( Guy(ali).try_increaseBidSize(id, 100 ether, 1 ether));
    }
    function test_no_deal_after_end() public {
        // if there are no bids and the auction ends, then it should not
        // be refundable to the creator. Rather, it restarts indefinitely.
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        assertTrue(!Guy(ali).try_settleAuction(id));
        hevm.warp(now + 2 weeks);
        assertTrue(!Guy(ali).try_settleAuction(id));
        assertTrue( Guy(ali).try_restartAuction(id));
        assertTrue(!Guy(ali).try_settleAuction(id));
    }
    function test_terminate_prematurely_increase_bid() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });

        Guy(ali).increaseBidSize(id, 100 ether, 1 ether);
        // initialBid taken from bidder
        assertEq(cdpEngine.coin_balance(ali),   199 ether);
        assertEq(cdpEngine.coin_balance(auctionIncomeRecipient), 1 ether);

        cdpEngine.mint(address(this), 1 ether);
        collateralAuctionHouse.terminateAuctionPrematurely(id);
        // initialBid is refunded to bidder from caller
        assertEq(cdpEngine.coin_balance(ali),            200 ether);
        assertEq(cdpEngine.coin_balance(address(this)),    0 ether);
        // collateralType go to caller
        assertEq(cdpEngine.token_collateral_balance(address(this)), 1000 ether);
    }
    function test_terminate_prematurely_decrease_sold() public {
        uint id = collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                                      , amountToRaise: 50 ether
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      , initialBid: 0
                                                      });
        Guy(ali).increaseBidSize(id, 100 ether,  1 ether);
        Guy(bob).increaseBidSize(id, 100 ether, 50 ether);
        Guy(ali).decreaseSoldAmount(id,  95 ether, 50 ether);

        // cannot terminate_prematurely in the dent phase
        assertTrue(!Guy(ali).try_english_terminateAuctionPrematurely(id));
    }
}

contract FixedDiscountCollateralAuctionHouseTest is DSTest {
    Hevm hevm;

    CDPEngine_ cdpEngine;
    FixedDiscountCollateralAuctionHouse collateralAuctionHouse;
    OracleRelayer oracleRelayer;
    Feed    feed;

    address ali;
    address bob;
    address auctionIncomeRecipient;
    address cdpAuctioned = address(0xacab);

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;
    uint constant RAD = 10 ** 45;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        cdpEngine = new CDPEngine_();

        cdpEngine.initializeCollateralType("collateralType");
        cdpEngine.set_collateral_type("collateralType");

        collateralAuctionHouse = new FixedDiscountCollateralAuctionHouse(address(cdpEngine), "collateralType");

        oracleRelayer = new OracleRelayer(address(cdpEngine));
        oracleRelayer.modifyParameters("redemptionPrice", 5 * RAY);
        collateralAuctionHouse.modifyParameters("oracleRelayer", address(oracleRelayer));

        feed = new Feed(bytes32(uint256(0)), true);
        collateralAuctionHouse.modifyParameters("orcl", address(feed));

        ali = address(new Guy(EnglishCollateralAuctionHouse(address(0)), collateralAuctionHouse));
        bob = address(new Guy(EnglishCollateralAuctionHouse(address(0)), collateralAuctionHouse));
        auctionIncomeRecipient = address(new Gal());

        Guy(ali).approveCDPModification("fixed", address(collateralAuctionHouse));
        Guy(bob).approveCDPModification("fixed", address(collateralAuctionHouse));
        cdpEngine.approveCDPModification(address(collateralAuctionHouse));

        cdpEngine.modifyCollateralBalance("collateralType", address(this), 1000 ether);
        cdpEngine.mint(ali, 200 ether);
        cdpEngine.mint(bob, 200 ether);
    }

    // --- Math ---
    function addition(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function subtract(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function wmultiply(uint x, uint y) internal pure returns (uint z) {
        z = multiply(x, y) / WAD;
    }
    function rdivide(uint x, uint y) internal pure returns (uint z) {
      z = multiply(x, RAY) / y;
    }
    function wdivide(uint x, uint y) internal pure returns (uint z) {
      z = multiply(x, WAD) / y;
    }

    function test_modifyParameters() public {
        collateralAuctionHouse.modifyParameters("discount", 0.90E18);
        collateralAuctionHouse.modifyParameters("minimumBid", 50 * WAD);

        assertEq(collateralAuctionHouse.discount(), 0.90E18);
        assertEq(collateralAuctionHouse.minimumBid(), 50 * WAD);
    }
    function testFail_no_discount() public {
        collateralAuctionHouse.modifyParameters("discount", 1 ether);
    }
    function test_startAuction() public {
        collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                            , amountToRaise: 50 ether
                                            , forgoneCollateralReceiver: cdpAuctioned
                                            , auctionIncomeRecipient: auctionIncomeRecipient
                                            });
    }
    function testFail_buyCollateral_inexistent_auction() public {
        // can't buyCollateral on non-existent
        collateralAuctionHouse.buyCollateral(42, 0, 5 * WAD);
    }
    function testFail_buyCollateral_null_bid() public {
        collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                            , amountToRaise: 50 ether
                                            , forgoneCollateralReceiver: cdpAuctioned
                                            , auctionIncomeRecipient: auctionIncomeRecipient
                                            });
        // can't buy collateral on non-existent
        collateralAuctionHouse.buyCollateral(1, 0, 0);
    }
    function testFail_faulty_oracle_price() public {
        Feed faultyFeed = new Feed(bytes32(uint256(1)), false);
        collateralAuctionHouse.modifyParameters("orcl", address(faultyFeed));
        collateralAuctionHouse.startAuction({ amountToSell: 100 ether
                                            , amountToRaise: 50 ether
                                            , forgoneCollateralReceiver: cdpAuctioned
                                            , auctionIncomeRecipient: auctionIncomeRecipient
                                            });
        collateralAuctionHouse.buyCollateral(1, 0, 5 * WAD);
    }
    function test_buy_some_collateral() public {
        oracleRelayer.modifyParameters("redemptionPrice", RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });
        Guy(ali).buyCollateral(id, 0, 25 * WAD);

        (uint256 raisedAmount, uint256 soldAmount, , , , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 25 * RAD);
        assertEq(soldAmount, 131578947368421052);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 1 ether - 131578947368421052);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 131578947368421052);
    }
    function test_buy_all_collateral() public {
        oracleRelayer.modifyParameters("redemptionPrice", 2 * RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        assertEq(collateralAuctionHouse.getDiscountedRedemptionCollateralPrice(bytes32(uint256(200 ether)), 0.95E18), 95 ether);
        assertEq(collateralAuctionHouse.getCollateralBought(id, 0, 50 * WAD), 526315789473684210);
        Guy(ali).buyCollateral(id, 0, 50 * WAD);

        (uint256 raisedAmount, uint256 soldAmount, uint256 amountToSell, uint256 amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 526315789473684210);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 1 ether - 526315789473684210);
    }
    function test_buyCollateral_adjusted_bid_higher_than_leftover() public {
        oracleRelayer.modifyParameters("redemptionPrice", 2 * RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        Guy(ali).buyCollateral(id, 0, 49.9E18);
        (uint256 raisedAmount, uint256 soldAmount, uint256 amountToSell, uint256 amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 49.9E45);
        assertEq(soldAmount, 525263157894736842);
        assertEq(amountToSell, 1 ether);
        assertEq(amountToRaise, 50 * RAD);

        assertEq(collateralAuctionHouse.getCollateralBought(id, 0, 5 * WAD), 11578947368421052);
        assertTrue(11578947368421052 + 525263157894736842 > 526315789473684210);

        Guy(ali).buyCollateral(id, 0, 5 * WAD);
        (raisedAmount, soldAmount, amountToSell, amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 51 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 11578947368421052 + 525263157894736842);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 1 ether - (11578947368421052 + 525263157894736842));
    }
    function test_buyCollateral_small_market_price() public {
        feed.set_val(bytes32(uint256(0.01 ether)));
        oracleRelayer.modifyParameters("redemptionPrice", 2 * RAY);

        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        Guy(ali).buyCollateral(id, 0, 5 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 5 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 1 ether);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 0);
    }
    function test_buyCollateral_small_redemption_price() public {
        oracleRelayer.modifyParameters("redemptionPrice", 0.01E27);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        Guy(ali).buyCollateral(id, 0, 50 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 2631578947368421);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 1 ether - 2631578947368421);
    }
    function test_buyCollateral_insignificant_leftover_to_raise() public {
        oracleRelayer.modifyParameters("redemptionPrice", RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });
        Guy(ali).buyCollateral(id, 0, 49.99E18);
        Guy(ali).buyCollateral(id, 0, 5 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 51 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 268421052631578946);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 1 ether - 268421052631578946);
    }
    function test_big_discount_buy() public {
        oracleRelayer.modifyParameters("redemptionPrice", RAY);
        collateralAuctionHouse.modifyParameters("discount", 0.10E18);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });
        Guy(ali).buyCollateral(id, 0, 50 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 1000000000000000000);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 0);
    }
    function test_small_discount_buy() public {
        oracleRelayer.modifyParameters("redemptionPrice", RAY);
        collateralAuctionHouse.modifyParameters("discount", 0.99E18);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });
        Guy(ali).buyCollateral(id, 0, 50 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 252525252525252525);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 1 ether - 252525252525252525);
    }
    function test_non_null_amountToBuy() public {
        oracleRelayer.modifyParameters("redemptionPrice", 2 * RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        Guy(ali).buyCollateral(id, 0.01 ether, 50 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 0.01 ether);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 0.99 ether);
    }
    function test_big_amountToBuy() public {
        oracleRelayer.modifyParameters("redemptionPrice", 2 * RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        Guy(ali).buyCollateral(id, 10000 ether, 50 * WAD);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 50 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 526315789473684210);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 1 ether - 526315789473684210);
    }
    function testFail_terminate_inexistent() public {
        collateralAuctionHouse.terminateAuctionPrematurely(1);
    }
    function test_terminateAuctionPrematurely() public {
        oracleRelayer.modifyParameters("redemptionPrice", 2 * RAY);
        feed.set_val(bytes32(uint256(200 ether)));
        cdpEngine.mint(ali, 200 * RAD - 200 ether);

        uint collateralAmountPreBid = cdpEngine.tokenCollateral("collateralType", address(ali));

        uint id = collateralAuctionHouse.startAuction({ amountToSell: 1 ether
                                                      , amountToRaise: 50 * RAD
                                                      , forgoneCollateralReceiver: cdpAuctioned
                                                      , auctionIncomeRecipient: auctionIncomeRecipient
                                                      });

        Guy(ali).buyCollateral(id, 0, 25 * WAD);
        collateralAuctionHouse.terminateAuctionPrematurely(1);

        (uint raisedAmount, uint soldAmount, uint amountToSell, uint amountToRaise, , ) = collateralAuctionHouse.bids(id);
        assertEq(raisedAmount, 0);
        assertEq(soldAmount, 0);
        assertEq(amountToSell, 0);
        assertEq(amountToRaise, 0);

        assertEq(cdpEngine.coinBalance(auctionIncomeRecipient), 25 * RAD);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(collateralAuctionHouse)), 0);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(this)), 999736842105263157895);
        assertEq(addition(999736842105263157895, 263157894736842105), 1000 ether);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(ali)) - collateralAmountPreBid, 263157894736842105);
        assertEq(cdpEngine.tokenCollateral("collateralType", address(cdpAuctioned)), 0);
    }
}
