// Start - Support direct Mocha run & debug
import 'hardhat'
import '@nomiclabs/hardhat-ethers'
// End - Support direct Mocha run & debug

import chai, {expect} from 'chai'
import {ethers} from 'hardhat'
import {before} from 'mocha'
import {solidity} from 'ethereum-waffle'
import {BitDAO} from '../typechain'

chai.use(solidity)

const TEN_OCTILLIAN = 10000000000000000000000000000n
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

describe('BitDAO token contract', async () => {
  before(async () => {
    admin = await signer(0)
    dao = await bitDao(admin)
  })

  it('name is BitDAO', async () => {
    expect(await dao.name()).to.equal('BitDAO')
  })

  it('symbol is BIT', async () => {
    expect(await dao.symbol()).to.equal('BIT')
  })

  it('zero votes for the admin by default', async () => {
    expect(await dao.getCurrentVotes(admin)).to.equal(0)
  })

  it('contract creator gets 10 Octillian (1e28 / 1e10 * 1e18) BITs', async () => {
    expect(await dao.balanceOf(admin)).to.equal(TEN_OCTILLIAN)
  })

  it('minting BIT not allowed', async () => {
    expect(dao.transferFrom(ZERO_ADDRESS, admin, 5)).to.be.revertedWith(
      'ERC20: transfer from the zero address'
    )
  })

  it('burning BIT not allowed', async () => {
    expect(dao.transferFrom(admin, ZERO_ADDRESS, 5)).to.be.revertedWith(
      'ERC20: transfer to the zero address'
    )
  })

  describe('delegate', async () => {
    beforeEach(async () => {
      admin = await signer(0)
      delegateOne = await signer(1)
      delegateTwo = await signer(2)
      dao = await bitDao(admin)
    })

    it('admin assign ten octillian (all) votes to itself', async () => {
      expect(await dao.getCurrentVotes(admin)).to.equal(0)

      await dao.delegate(admin)

      expect(await dao.getCurrentVotes(admin)).to.equal(TEN_OCTILLIAN)
    })

    it('admin assign ten octillian (all) votes to a delegate', async () => {
      expect(await dao.getCurrentVotes(admin)).to.equal(0)
      expect(await dao.getCurrentVotes(delegateOne)).to.equal(0)

      await dao.delegate(delegateOne)

      expect(await dao.getCurrentVotes(admin)).to.equal(0)
      expect(await dao.getCurrentVotes(delegateOne)).to.equal(TEN_OCTILLIAN)
    })

    it('admin assign ten octillian (all) votes to a delegate, reassigns to another', async () => {
      expect(await dao.getCurrentVotes(admin)).to.equal(0)
      expect(await dao.getCurrentVotes(delegateOne)).to.equal(0)
      expect(await dao.getCurrentVotes(delegateTwo)).to.equal(0)

      await dao.delegate(delegateOne)
      await dao.delegate(delegateTwo)

      expect(await dao.getCurrentVotes(admin)).to.equal(0)
      expect(await dao.getCurrentVotes(delegateOne)).to.equal(0)
      expect(await dao.getCurrentVotes(delegateTwo)).to.equal(TEN_OCTILLIAN)
    })
  })

  //TODO verify emitted events

  let admin: string
  let dao: BitDAO
  let delegateOne: string
  let delegateTwo: string
})

async function bitDao(creatorAccount: string): Promise<BitDAO> {
  const factory = await ethers.getContractFactory('BitDAO')
  const dao = <BitDAO>await factory.deploy(creatorAccount)
  return dao.deployed()
}

async function signer(index: number): Promise<string> {
  const signers = await ethers.getSigners()
  expect(signers.length).is.greaterThan(index)
  return signers[index].address
}
