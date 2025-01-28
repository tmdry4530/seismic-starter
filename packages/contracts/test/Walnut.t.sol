// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Walnut} from "../src/Walnut.sol";

contract WalnutTest is Test {
    Walnut public walnut;

    function setUp() public {
        walnut = new Walnut(2, suint256(0));

        saddress a = saddress(0x123);
        console.log(address(a));
    }

    function test_Cracked() public {
        walnut.shake(suint256(1));
        walnut.hit();
        walnut.hit();
        assertEq(walnut.look(), 1);
    }

    function testFail_EarlyLook() public {
        walnut.hit();
        walnut.shake(suint256(1));
        walnut.look();
    }

    function testFail_EarlyReset() public {
        walnut.hit();
        walnut.shake(suint256(1));
        walnut.reset();
    }

    function test_ManyActions() public {
        uint256 shakes = 0;
        for (uint256 i = 0; i < 50; i++) {
            // Only shake if the walnut is still intact
            if (walnut.getShellStrength() > 0) {
                if (i % 25 == 0) {
                    walnut.hit();
                } else {
                    // Shake a random number of times between 1-3
                    uint256 numShakes = (i % 3) + 1;
                    walnut.shake(suint256(numShakes));
                    shakes += numShakes;
                }
            }
        }
        assertEq(walnut.look(), shakes);
    }

    function test_RevertWhen_NonContributorTriesToLook() public {
        // Address that will attempt to call 'look' without contributing
        address nonContributor = address(0xabcd);

        // Ensure the shell is cracked
        walnut.hit();
        walnut.shake(suint256(3));
        walnut.hit();

            // Expect the 'look' function to revert with "NOT_A_CONTRIBUTOR" error
        vm.prank(address(nonContributor));
        console.log(address(this));
        vm.expectRevert("NOT_A_CONTRIBUTOR");
        walnut.look();
        assertEq(walnut.look(), 3);    
    }

    function test_ContributorInRound2() public {
        // Address that will become a contributor in round 2
        address contributorRound2 = address(0xabcd);

        // Round 1: Walnut broken by address(this)
        walnut.hit(); // Hit 1 by address(this)
        walnut.hit(); // Hit 2 by address(this)
        assertEq(walnut.look(), 0); // Verify the walnut is cracked and look() works for address(this)

        // Reset the walnut, moving to round 2
        walnut.reset();

        // Round 2: Walnut broken by contributorRound2
        vm.prank(contributorRound2);
        walnut.hit(); // Hit 1 by contributorRound2

        vm.prank(contributorRound2);
        walnut.shake(suint256(5)); // Shake 5 times by contributorRound2

        vm.prank(contributorRound2);
        walnut.hit(); // Hit 2 by contributorRound2

        // Verify contributorRound2 can call look() in round 2
        vm.prank(contributorRound2);
        assertEq(walnut.look(), 5); // Expect the number to be 5 due to 5 shakes

        // Verify address(this) cannot call look() in round 2
        vm.expectRevert("NOT_A_CONTRIBUTOR");
        walnut.look();
    }

}

