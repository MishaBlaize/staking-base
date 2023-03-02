import type { SnapshotRestorer } from "@nomicfoundation/hardhat-network-helpers";
import { takeSnapshot } from "@nomicfoundation/hardhat-network-helpers";

import { expect } from "chai";
import { ethers } from "hardhat";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import type { Staking, MockToken } from "../typechain-types";

describe("Staking", function () {
    let snapshotA: SnapshotRestorer;

    // Signers.
    let deployer: SignerWithAddress, user: SignerWithAddress;
    let mockToken1: MockToken;
    let mockToken2: MockToken;
    let mockToken3: MockToken;
    let stakingToken: MockToken;
    let staking: Staking;
    const DAY_IN_SECONDS = 86400;
    const MONTH_IN_SECONDS = 2592000;
    const YEAR_IN_SECONDS = 31536000;
    before(async () => {
        // Getting of signers.
        [deployer, user] = await ethers.getSigners();

        // Deploy 3 mock tokens for rewards.
        const MockToken = await ethers.getContractFactory("MockToken");
        mockToken1 = await MockToken.deploy();
        await mockToken1.deployed();

        mockToken2 = await MockToken.deploy();
        await mockToken2.deployed();

        mockToken3 = await MockToken.deploy();
        await mockToken3.deployed();

        // Deploy mock token as staking token.
        stakingToken = await MockToken.deploy();
        await stakingToken.deployed();

        // Deployment of the factory.
        const Staking = await ethers.getContractFactory("Staking");
        staking = await Staking.deploy();
        await staking.deployed();


        snapshotA = await takeSnapshot();
    });


    describe("# Initialization", function () {
        afterEach(async () => await snapshotA.restore());

        it("Initialize Staking contract", async () => {
            await mockToken1.approve(staking.address, ethers.utils.parseEther("100"));
            await mockToken2.approve(staking.address, ethers.utils.parseEther("200"));
            await mockToken3.approve(staking.address, ethers.utils.parseEther("300"));

            await staking.initialize(
                deployer.address,
                [mockToken1.address, mockToken2.address, mockToken3.address],
                stakingToken.address,
                [ethers.utils.parseEther("100"), ethers.utils.parseEther("200"), ethers.utils.parseEther("300")],
                MONTH_IN_SECONDS
            );
        });
    });

    describe("# Staking", function () {
        before(async () => {
            await mockToken1.approve(staking.address, ethers.utils.parseEther("100"));
            await mockToken2.approve(staking.address, ethers.utils.parseEther("200"));
            await mockToken3.approve(staking.address, ethers.utils.parseEther("300"));

            await staking.initialize(
                deployer.address,
                [mockToken1.address, mockToken2.address, mockToken3.address],
                stakingToken.address,
                [ethers.utils.parseEther("100"), ethers.utils.parseEther("200"), ethers.utils.parseEther("300")],
                MONTH_IN_SECONDS
            );
        });
        afterEach(async () => await snapshotA.restore());

        it("Stake", async () => {
            await stakingToken.transfer(user.address, ethers.utils.parseEther("100"));
            await stakingToken.connect(user).approve(staking.address, ethers.utils.parseEther("100"));
            await expect(
                await staking.connect(user).stake(
                    stakingToken.address,
                    ethers.utils.parseEther("100")
                )
            ).to.emit(staking, "Staked")
            .withArgs(
                stakingToken.address,
                user.address,
                ethers.utils.parseEther("100")
            );
        });
    });

    describe("# Withdraw", function () {
        before(async () => {
            await mockToken1.approve(staking.address, ethers.utils.parseEther("100"));
            await mockToken2.approve(staking.address, ethers.utils.parseEther("200"));
            await mockToken3.approve(staking.address, ethers.utils.parseEther("400"));
            await staking.initialize(
                deployer.address,
                [mockToken1.address, mockToken2.address, mockToken3.address],
                stakingToken.address,
                [ethers.utils.parseEther("100"), ethers.utils.parseEther("200"), ethers.utils.parseEther("400")],
                MONTH_IN_SECONDS
            );
            snapshotA = await takeSnapshot();
        });
        afterEach(async () => await snapshotA.restore());

        it("Unstake directly", async () => {
            await stakingToken.transfer(user.address, ethers.utils.parseEther("100"));
            await stakingToken.connect(user).approve(staking.address, ethers.utils.parseEther("100"));
            await staking.connect(user).stake(
                stakingToken.address,
                ethers.utils.parseEther("100")
            );
            await expect(
                await staking.connect(user).withdraw(
                    stakingToken.address,
                    ethers.utils.parseEther("100")
                )
            ).to.emit(staking, "Withdrawn")
            .withArgs(
                stakingToken.address,
                user.address,
                ethers.utils.parseEther("100")
            );
        });

        it("Exit after 1 day", async () => {
            await stakingToken.transfer(user.address, ethers.utils.parseEther("100"));
            await stakingToken.connect(user).approve(staking.address, ethers.utils.parseEther("100"));
            await staking.connect(user).stake(
                stakingToken.address,
                ethers.utils.parseEther("100")
            );
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine", []);

            const tx = await staking.connect(user).exit(
                stakingToken.address
            );
            await expect(
                tx
            ).to.emit(staking, "Withdrawn")
            .withArgs(
                stakingToken.address,
                user.address,
                ethers.utils.parseEther("100")
            );
            await expect(
                tx
            ).to.emit(staking, "RewardPaid");
        });

        it("Exit after 1 month", async () => {
            await stakingToken.transfer(user.address, ethers.utils.parseEther("100"));
            await stakingToken.connect(user).approve(staking.address, ethers.utils.parseEther("100"));
            await staking.connect(user).stake(
                stakingToken.address,
                ethers.utils.parseEther("100")
            );
            await ethers.provider.send("evm_increaseTime", [2592000]);
            await ethers.provider.send("evm_mine", []);

            const tx = await staking.connect(user).exit(
                stakingToken.address
            );
            await expect(
                tx
            ).to.emit(staking, "Withdrawn")
            .withArgs(
                stakingToken.address,
                user.address,
                ethers.utils.parseEther("100")
            );
            await expect(
                tx
            ).to.emit(staking, "RewardPaid");
        });

        it("Exit after new tokens added to rewards", async () => {
            await stakingToken.transfer(user.address, ethers.utils.parseEther("100"));
            await stakingToken.connect(user).approve(staking.address, ethers.utils.parseEther("100"));
            await staking.connect(user).stake(
                stakingToken.address,
                ethers.utils.parseEther("100")
            );
            await ethers.provider.send("evm_increaseTime", [MONTH_IN_SECONDS]);
            await ethers.provider.send("evm_mine", []);
            await ethers.provider.send("evm_increaseTime", [MONTH_IN_SECONDS]);
            await ethers.provider.send("evm_mine", []);

            await mockToken1.connect(deployer).approve(staking.address, ethers.utils.parseEther("400"));
            // await staking.connect(deployer).addRewardsToPool(
            //     stakingToken.address,
            //     mockToken1.address,
            //     ethers.utils.parseEther("400"),
            //     MONTH_IN_SECONDS
            // );
            await ethers.provider.send("evm_increaseTime", [MONTH_IN_SECONDS+1]);
            await ethers.provider.send("evm_mine", []);
            await ethers.provider.send("evm_increaseTime", [MONTH_IN_SECONDS+1]);
            await ethers.provider.send("evm_mine", []);
            const tx = await staking.connect(user).exit(
                stakingToken.address
            );
            await expect(
                tx
            ).to.emit(staking, "Withdrawn")
            .withArgs(
                stakingToken.address,
                user.address,
                ethers.utils.parseEther("100")
            );
            await expect(
                tx
            ).to.emit(staking, "RewardPaid");
            expect(
                (
                    await staking.getRewardTokenState(
                        stakingToken.address,
                        mockToken1.address
                    )
                )[0]
            ).to.equal(0)
        });
    });
});
