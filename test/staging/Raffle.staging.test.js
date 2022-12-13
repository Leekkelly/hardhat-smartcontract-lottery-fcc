const { assert, expect } = require("chai") //console -> chai
const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

developmentChains.includes(network.name) 
    ? describe.skip //run this only main net or test net
    : describe("Raffle", function() {
        let raffle, raffleEntranceFee, deployer
        

        beforeEach(async function() {
            deployer = (await getNamedAccounts()).deployer
            raffle = await ethers.getContract("Raffle", deployer)
            raffleEntranceFee = await raffle.getEntranceFee()
        })

        describe("fulfillRandomWords", function() {
            it("works with live Chainlink Keepers and Chainlink VRF, we get a random winner", async function () {
                // enter the raffle
                const startingTimeStamp = await raffle.getLatestTimeStamp()
                const accounts = await ethers.getSigners() 

                await new Promise(async (resolve, reject) => {
                    //setup listener before we enter the raffle
                    //just incase the blockchain moves really fast
                    raffle.once("WinnerPicked", async () => {
                        console.log("WinnerPicked event fired!")
                        
                        try {    
                            // add our asserts here
                            const recentWinner = await raffle.getRecentWinner()
                            const raffleState = await raffle.getRaffleState()
                            const winnerEndingBalance = await accounts[0].getBalance()
                            const endingTimeStamp = await raffle.getLatestTimeStamp()

                            await expect(raffle.getPlayer(0)).to.be.reverted
                            assert.equal(recentWinner.toString(), accounts[0].address)
                            assert.equal(raffleState, 0)
                            assert.equal(
                                winnerEndingBalance.toString(),
                                winnerStartingBalance.add(raffleEntranceFee).toString()
                            )
                            assert(endingTimeStamp > startingTimeStamp)
                            resolve()
                        } catch (error) {
                             console.log(error)
                             reject(e)
                        }
                    })
                    // then entering the raffle
                    await raffle.enterRaffle({ value: raffleEntranceFee })
                    const winnerStartingBalance = await accounts[0].getBalance()

                    // add this code WONT complete until our listener has finished listening
                })

                

            })
        })
    })