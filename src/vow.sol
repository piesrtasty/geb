/// vow.sol -- Mai settlement module

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.5.15;

import "./lib.sol";

contract FlopLike {
    function kick(address gal, uint lot, uint bid) external returns (uint);
    function cage() external;
    function live() external returns (uint);
}

contract FlapLike {
    function kick(uint lot, uint bid) external returns (uint);
    function cage(int) external;
    function live() external returns (uint);
}

contract VatLike {
    function mai (address) external view returns (int);
    function sin (address) external view returns (int);
    function heal(int256)  external;
    function hope(address) external;
    function nope(address) external;
}

contract Vow is LibNote {
    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address usr) external note auth { require(live == 1, "Vow/not-live"); wards[usr] = 1; }
    function deny(address usr) external note auth { wards[usr] = 0; }
    modifier auth {
      require(wards[msg.sender] == 1, "Vow/not-authorized");
      _;
    }

    // --- Data ---
    VatLike  public vat;
    FlapLike public flapper;
    FlopLike public flopper;

    mapping (uint256 => uint256) public sin; // debt queue
    uint256 public Sin;   // queued debt            [rad]
    uint256 public Ash;   // on-auction debt        [rad]

    uint256 public wait;  // flop delay
    uint256 public dump;  // flop initial lot size  [wad]
    uint256 public sump;  // flop fixed bid size    [rad]

    uint256 public bump;  // flap fixed lot size    [rad]
    uint256 public hump;  // surplus buffer         [rad]

    uint256 public live;

    // --- Init ---
    constructor(address vat_, address flapper_, address flopper_) public {
        wards[msg.sender] = 1;
        vat     = VatLike(vat_);
        flapper = FlapLike(flapper_);
        flopper = FlopLike(flopper_);
        vat.hope(flapper_);
        live = 1;
    }

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function add(int x, int y) internal pure returns (int z) {
        z = x + y;
        require(y >= 0 || z <= x);
        require(y <= 0 || z >= x);
    }
    function add(int x, uint y) internal pure returns (int z) {
        z = x + int(y);
        require(x >= 0 || z <= int(y));
        require(x <= 0 || z >= int(y));
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function sub(int x, uint y) internal pure returns (int z) {
        z = x - (int(y));
        require(x >= 0 || z <= int(y));
        require(x <= 0 || z >= int(y));
    }
    function sub(int x, int y) internal pure returns (int z) {
        z = x - y;
        require(y <= 0 || z <= x);
        require(y >= 0 || z >= x);
    }
    function min(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }

    // --- Administration ---
    function file(bytes32 what, uint data) external note auth {
        if (what == "wait") wait = data;
        else if (what == "bump") bump = data;
        else if (what == "sump") sump = data;
        else if (what == "dump") dump = data;
        else if (what == "hump") hump = data;
        else revert("Vow/file-unrecognized-param");
    }

    function file(bytes32 what, address data) external note auth {
      if (what == "flapper") {
          vat.nope(address(flapper));
          flapper = FlapLike(data);
          vat.hope(data);
      }
      else if (what == "flopper") flopper = FlopLike(data);
      else revert("Vow/file-unrecognized-param");
    }

    // Push to debt-queue
    function fess(uint tab) external note auth {
        sin[now] = add(sin[now], tab);
        Sin = add(Sin, tab);
    }
    // Pop from debt-queue
    function flog(uint era) external note {
        require(add(era, wait) <= now, "Vow/wait-not-finished");
        Sin = sub(Sin, sin[era]);
        sin[era] = 0;
    }

    // Debt settlement
    function heal(int rad) external note {
        bool rich = (vat.mai(address(this)) < 0) ? (rad >= vat.mai(address(this)) && rad <= 0) : (rad <= vat.mai(address(this)) && rad >= 0);
        require(rich, "Vow/insufficient-surplus");
        require(rad <= sub(sub(vat.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        vat.heal(rad);
    }
    //TODO: rad should be int
    function kiss(uint rad) external note {
        require(rad <= Ash, "Vow/not-enough-ash");
        require(int(rad) <= vat.mai(address(this)), "Vow/insufficient-surplus");
        Ash = sub(Ash, rad);
        vat.heal(int(rad));
    }

    // Debt auction
    function flop() external note returns (uint id) {
        require(int(sump) <= sub(sub(vat.sin(address(this)), Sin), Ash), "Vow/insufficient-debt");
        require(vat.mai(address(this)) == 0, "Vow/surplus-not-zero");
        Ash = add(Ash, sump);
        id = flopper.kick(address(this), dump, sump);
    }
    // Surplus auction
    function flap() external note returns (uint id) {
        require(vat.mai(address(this)) >= add(add(vat.sin(address(this)), bump), hump), "Vow/insufficient-surplus");
        require(sub(sub(vat.sin(address(this)), Sin), Ash) == 0, "Vow/debt-not-zero");
        id = flapper.kick(bump, 0);
    }

    function cage() external note auth {
        require(live == 1, "Vow/not-live");
        live = 0;
        Sin = 0;
        Ash = 0;
        flapper.cage(vat.mai(address(flapper)));
        flopper.cage();
        vat.heal(min(vat.mai(address(this)), vat.sin(address(this))));
    }
}