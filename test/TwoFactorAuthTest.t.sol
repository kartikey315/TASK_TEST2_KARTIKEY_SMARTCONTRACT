// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {TwoFactorAuth} from "../src/TwoFactorAuth.sol";

contract TwoFactorAuthTest is Test {
    TwoFactorAuth public tfa;
    address user1 = makeAddr("USER1");
    address user2 = makeAddr("USER2");
    uint256 constant INITIAL_OTP_SEED = 12345;
    uint256 constant OTP_VALIDITY_PERIOD = 30 seconds;

    function setUp() public {
        tfa = new TwoFactorAuth();
    }

    function testUserRegistration() public {
        string memory username = "user1";
        address publicKey = address(user1);

        vm.prank(user1);
        tfa.registerUser(username, publicKey, INITIAL_OTP_SEED);

        // Try to register the same username again
        vm.expectRevert("Username already exists");
        vm.prank(user2);
        tfa.registerUser(username, publicKey, INITIAL_OTP_SEED);
    }

    function testOTPGeneration() public {
        string memory username = "bob";
        address publicKey = address(user1);

        vm.prank(user1);
        tfa.registerUser(username, publicKey, INITIAL_OTP_SEED);

        uint256 otp1 = tfa.generateOTP(username);
        assertGt(otp1, 0, "OTP should be greater than 0");
        assertLt(otp1, 1000000, "OTP should be less than 1,000,000");

        // OTP should remain the same within the validity period
        vm.warp(block.timestamp + OTP_VALIDITY_PERIOD - 2);
        uint256 otp2 = tfa.generateOTP(username);
        assertEq(otp1, otp2, "OTP should not change within validity period");

        // OTP should change after validity period
        vm.warp(block.timestamp + 10);
        uint256 otp3 = tfa.generateOTP(username);
        assertNotEq(otp1, otp3, "OTP should change after validity period");
    }

    function testAuthentication() public {
        string memory username = "charlie";
        vm.warp(block.timestamp + 100);

        uint256 privateKey = 0x7ae1855aaa11f56bf7d2adbaa46391c0de511f88c7a35db8c05014967a543e1e; // Example private key for testing

        address publicKey = vm.addr(privateKey);

        vm.startPrank(publicKey);
        tfa.registerUser(username, publicKey, INITIAL_OTP_SEED);

        uint256 otp = tfa.generateOTP(username);

        bytes32 messageHash = keccak256(abi.encodePacked(username, otp));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        tfa.authenticate(username, otp, signature);
        vm.stopPrank();

        // Test invalid OTP
        vm.prank(publicKey);
        vm.expectRevert("Invalid OTP");
        tfa.authenticate(username, otp + 1, signature);

        // Test replay attack
        vm.prank(publicKey);
        vm.expectRevert("OTP already used");
        tfa.authenticate(username, otp, signature);

        // Test invalid signature
        vm.warp(block.timestamp + OTP_VALIDITY_PERIOD + 5);
        otp = tfa.generateOTP(username);
        messageHash = keccak256(abi.encodePacked(username, otp));
        (v, r, s) = vm.sign(2, messageHash); // Sign with a different private key
        signature = abi.encodePacked(r, s, v);

        vm.prank(publicKey);
        vm.expectRevert("Invalid signature");
        tfa.authenticate(username, otp, signature);
    }

    function testUpdateOtpSeed() public {
        string memory username = "david";
        uint256 newOtpSeed = 67890;

        uint256 privateKey = 0x7ae1855aaa11f56bf7d2adbaa46391c0de511f88c7a35db8c05014967a543e1e; // Example private key for testing

        address publicKey = vm.addr(privateKey);

        vm.startPrank(publicKey);
        tfa.registerUser(username, publicKey, INITIAL_OTP_SEED);

        uint256 otp = tfa.generateOTP(username);

        bytes32 messageHash = keccak256(abi.encodePacked(username, newOtpSeed));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        tfa.updateOtpSeed(username, newOtpSeed, signature);
        vm.stopPrank();

        // Test with invalid signature
        vm.prank(user1);
        messageHash = keccak256(abi.encodePacked(username, newOtpSeed + 1));
        (v, r, s) = vm.sign(1, messageHash);
        signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Invalid signature");
        tfa.updateOtpSeed(username, newOtpSeed + 1, signature);
    }

    function testNonExistentUser() public {
        vm.expectRevert("User not found");
        tfa.generateOTP("nonexistent");

        vm.expectRevert("User not found");
        tfa.authenticate("nonexistent", 123456, "0x");

        vm.expectRevert("User not found");
        tfa.updateOtpSeed("nonexistent", 123456, "0x");
    }

    function testFuzzingOTP(uint256 _otpSeed) public {
        string memory username = "eve";
        address publicKey = address(user1);

        vm.prank(user1);
        tfa.registerUser(username, publicKey, _otpSeed);

        uint256 otp = tfa.generateOTP(username);
        assertGt(otp, 0, "OTP should be greater than 0");
        assertLt(otp, 1000000, "OTP should be less than 1,000,000");
    }

    receive() external payable {}
}
