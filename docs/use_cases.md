# Use cases

Alice is launching a Community Grants program, and are seeking funds to add to their treasury. After
contributors bond the minimum BIT tokens needed with BitDAO's staking contract, Alice creates a
Snapshot proposal asking for funds. If the proposal passes, the BitDAO treasury transfers funds to
the grants treasury. In order for bond contributors to redeem the bond, the BitDAO multi-sig
determines whether to allow redemptions. Otherwise, funds are sent to the BitDAO treasury.

The process is as follows:

1. Alice executes createBond() in the BitDAO Staking Contract, which creates a new Bond record that
   has the fields:
    - id, uuid
    - bonded, tx.sender
    - minimum, uint256
    - redeemable, bool
    - redeem approval, multi-sig address

2. Alice makes a forum announcement requesting contributions from the ecosystem, providing the Bond
   id recorded in the Staking Contract, treasury address, and relevant documents such as mandate,
   policies, metrics, and team profiles.

3. Bond contributors send the minimum specified 150k BIT to the Bond; each contributor claims a Bond
   Certificate which can be traded, or redeemed depending on approval by the bond's multi-sig
   address.

4. Alice submits a BitDAO Snapshot proposal with the following information:
    - a request for 100 ETH from the BitDAO treasury, to be sent to the grants treasury
    - a pointer to the forum announcement
    - a pointer to the bond record

5. If the proposal passes, the BitDAO funds the grants treasury. If the proposal doesn't pass, the
   BitDAO multi-sig releases the bond for redemption by the contributors, and the process halts.

6. Alice executes the proposal

7. If Alice's project delivers requirements and meets metrics, a second BitDAO Snapshot proposal can
   be submitted to permit redemption of bond certificates.

8. If the proposal passes, the multi-sig address sets the bond's redeemable flag, so that
   contributions can be redeemed, sometimes with a reward. If the proposal doesn't pass, the bond is
   slashed by sending the bond contributions to the BitDAO treasury.

