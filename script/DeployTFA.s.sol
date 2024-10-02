//SPDX-License-Identifier:MIT

pragma solidity 0.8.26;

import {Script} from "forge-std/script.sol";
import {TwoFactorAuth} from "../src/TwoFactorAuth.sol";

contract DeployTFA is Script {
    function run() external returns (TwoFactorAuth) {
        vm.startBroadcast();
        TwoFactorAuth twoFactorAuth = new TwoFactorAuth();
        vm.stopBroadcast();
        return twoFactorAuth;
    }
}
