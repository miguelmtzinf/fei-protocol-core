// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Vm} from "../../utils/Vm.sol";
import {DSTest} from "../../utils/DSTest.sol";
import {PodFactory} from "../../../pods/PodFactory.sol";
import {PodAdminGateway} from "../../../pods/PodAdminGateway.sol";
import {IPodAdminGateway} from "../../../pods/IPodAdminGateway.sol";
import {mintOrcaTokens, getPodParams} from "../fixtures/Orca.sol";
import {IPodFactory} from "../../../pods/IPodFactory.sol";
import {TribeRoles} from "../../../core/TribeRoles.sol";
import {ICore} from "../../../core/ICore.sol";

// import "hardhat/console.sol";

contract PodAdminGatewayIntegrationTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    PodFactory factory;
    PodAdminGateway podAdminGateway;
    IPodFactory.PodConfig podConfig;
    uint256 podId;
    address votiumAddress;
    bytes32 testRole;

    address private core = 0x8d5ED43dCa8C2F7dFB20CF7b53CC7E593635d7b9;
    address private podController = 0xD89AAd5348A34E440E72f5F596De4fA7e291A3e8;
    address private memberToken = 0x0762aA185b6ed2dCA77945Ebe92De705e0C37AE3;
    address private feiDAOTimelock = 0xd51dbA7a94e1adEa403553A8235C302cEbF41a3c;
    address private securityGuardian =
        0xB8f482539F2d3Ae2C9ea6076894df36D1f632775;
    address private podExecutor = address(0x500);

    function setUp() public {
        // 1.0 Deploy pod factory
        factory = new PodFactory(core, podController, memberToken, podExecutor);

        // 2.0 Deploy multi-pod admin contract, to expose pod admin functionality
        podAdminGateway = new PodAdminGateway(core, memberToken);

        // 3.0 Make config for pod, mint Orca tokens to factory
        IPodFactory.PodConfig memory config = getPodParams(
            address(podAdminGateway),
            address(0x20)
        );
        podConfig = config;
        mintOrcaTokens(address(factory), 2, vm);

        // 4.0 Create pod
        vm.prank(feiDAOTimelock);
        (podId, ) = factory.createChildOptimisticPod(podConfig);

        // 5.0 Grant a test role admin access
        testRole = TribeRoles.VOTIUM_ROLE;
        votiumAddress = address(0x11);

        vm.prank(feiDAOTimelock);
        ICore(core).grantRole(testRole, votiumAddress);
    }

    /// @notice Validate that podAdminGateway contract pod admin, and initial state is valid
    function testInitialState() public {
        address podAdmin = factory.getPodAdmin(podId);
        assertEq(podAdmin, address(podAdminGateway));
    }

    /// @notice Validate that a podAdmin can be added for a particular pod by the GOVERNOR
    function testAddPodMember() public {
        address newMember = address(0x11);

        vm.prank(feiDAOTimelock);
        podAdminGateway.addPodMember(podId, newMember);
        uint256 numPodMembers = factory.getNumMembers(podId);
        assertEq(numPodMembers, podConfig.members.length + 1);
        address[] memory podMembers = factory.getPodMembers(podId);
        assertEq(podMembers[0], newMember);
    }

    /// @notice Validate that a podAdmin can be removed for a particular pod
    function testRemovePodMember() public {
        address memberToRemove = podConfig.members[0];

        vm.prank(feiDAOTimelock);
        podAdminGateway.removePodMember(podId, memberToRemove);

        uint256 numPodMembers = factory.getNumMembers(podId);
        assertEq(numPodMembers, podConfig.members.length - 1);

        address[] memory podMembers = factory.getPodMembers(podId);
        assertEq(podMembers[0], podConfig.members[1]);
        assertEq(podMembers[1], podConfig.members[2]);
    }

    /// @notice Validate that members can be removed by batch
    function testBatchRemoveMembers() public {
        address[] memory membersToRemove = new address[](2);
        membersToRemove[0] = podConfig.members[0];
        membersToRemove[1] = podConfig.members[1];

        vm.prank(feiDAOTimelock);
        podAdminGateway.batchRemovePodMember(podId, membersToRemove);

        uint256 numPodMembers = factory.getNumMembers(podId);
        assertEq(
            numPodMembers,
            podConfig.members.length - membersToRemove.length
        );

        // Should only be 1 podMember left - the last
        address[] memory podMembers = factory.getPodMembers(podId);
        assertEq(podMembers[0], podConfig.members[2]);
    }

    /// @notice Validate that members can be added by batch
    function testBatchAddMembers() public {
        address[] memory membersToAdd = new address[](2);
        membersToAdd[0] = address(0x11);
        membersToAdd[1] = address(0x12);

        vm.prank(feiDAOTimelock);
        podAdminGateway.batchAddPodMember(podId, membersToAdd);

        uint256 numPodMembers = factory.getNumMembers(podId);
        assertEq(numPodMembers, podConfig.members.length + membersToAdd.length);

        address[] memory podMembers = factory.getPodMembers(podId);
        assertEq(podMembers[0], membersToAdd[1]);
        assertEq(podMembers[1], membersToAdd[0]);
    }

    /// @notice Validate that a non-PodAdmin fails to call a priviledged admin method
    function testFailNonAdminRemoveMember() public {
        vm.expectRevert(bytes("UNAUTHORIZED"));
        podAdminGateway.removePodMember(podId, podConfig.members[0]);
    }

    /// @notice Validate that PodAddMemberRole is computed is expected
    function testGetPodAddMemberRole() public {
        bytes32 specificAddRole = keccak256(
            abi.encode(podId, "ORCA_POD", "POD_ADD_MEMBER_ROLE")
        );
        assertEq(specificAddRole, podAdminGateway.getPodAddMemberRole(podId));
    }

    /// @notice Validate that PodRemoveMemberRole is computed is expected
    function testRemovePodAddMemberRole() public {
        bytes32 specificRemoveRole = keccak256(
            abi.encode(podId, "ORCA_POD", "POD_REMOVE_MEMBER_ROLE")
        );
        assertEq(
            specificRemoveRole,
            podAdminGateway.getPodRemoveMemberRole(podId)
        );
    }

    /// @notice Validate that the specific add member pod admin can add
    function testSpecificAddMemberRole() public {
        address userWithSpecificRole = address(0x11);

        // Create role in core
        bytes32 specificPodAddRole = keccak256(
            abi.encode(podId, "ORCA_POD", "POD_ADD_MEMBER_ROLE")
        );

        vm.startPrank(feiDAOTimelock);
        ICore(core).createRole(specificPodAddRole, TribeRoles.GOVERNOR);
        ICore(core).grantRole(specificPodAddRole, userWithSpecificRole);
        vm.stopPrank();

        address newMember = address(0x12);
        vm.prank(userWithSpecificRole);
        podAdminGateway.addPodMember(podId, newMember);

        uint256 numPodMembers = factory.getNumMembers(podId);
        assertEq(numPodMembers, podConfig.members.length + 1);

        address[] memory podMembers = factory.getPodMembers(podId);
        assertEq(podMembers[0], newMember);
    }

    /// @notice Validate that the specific add member pod admin can remove members
    function testSpecificRemoveMemberRole() public {
        address userWithSpecificRole = address(0x11);

        // Create role in core
        bytes32 specificPodRemoveRole = keccak256(
            abi.encode(podId, "ORCA_POD", "POD_REMOVE_MEMBER_ROLE")
        );

        vm.startPrank(feiDAOTimelock);
        ICore(core).createRole(specificPodRemoveRole, TribeRoles.GOVERNOR);
        ICore(core).grantRole(specificPodRemoveRole, userWithSpecificRole);
        vm.stopPrank();

        vm.prank(userWithSpecificRole);
        podAdminGateway.removePodMember(podId, podConfig.members[0]);

        uint256 numPodMembers = factory.getNumMembers(podId);
        assertEq(numPodMembers, podConfig.members.length - 1);

        address[] memory podMembers = factory.getPodMembers(podId);
        assertEq(podMembers[0], podConfig.members[1]);
        assertEq(podMembers[1], podConfig.members[2]);
    }
}
