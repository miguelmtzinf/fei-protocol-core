pragma solidity ^0.8.4;

import "./IPegStabilityModule.sol";
import "../token/IFei.sol";

interface IPSMRouter {
    // ---------- View-Only API ----------

    /// @notice reference to the PegStabilityModule that this router interacts with
    function psm() external returns (IPegStabilityModule);

    /// @notice reference to the FEI contract used.    
    function fei() external returns (IFei);

    /// @notice mutex lock to prevent fallback function from being hit any other time than weth withdraw
    function redeemActive() external returns (bool);


    // ---------- State-Changing API ----------

    /// @notice Mints fei to the given address, with a minimum amount required
    /// @dev This wraps ETH and then calls into the PSM to mint the fei. We return the amount of fei minted.
    /// @param _to The address to mint fei to
    /// @param _minAmountOut The minimum amount of fei to mint
    function mint(address _to, uint256 _minAmountOut) external payable returns (uint256);


    /// @notice Redeems fei for ETH
    /// First pull user FEI into this contract
    /// Then call redeem on the PSM to turn the FEI into weth
    /// Withdraw all weth to eth in the router
    /// Send the eth to the specified recipient
    /// @param to the address to receive the eth
    /// @param amountFeiIn the amount of FEI to redeem
    /// @param minAmountOut the minimum amount of weth to receive
    function redeem(address to, uint256 amountFeiIn, uint256 minAmountOut) external returns (uint256 amountOut);
}
