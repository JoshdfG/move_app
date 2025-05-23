# Block Bequest

## Overview

The **Block Bequest** is a decentralized application built on the Sui blockchain, enabling users to create, manage, and distribute digital wills. It allows users to register assets, designate beneficiaries, store encrypted keys, and distribute assets according to predefined shares upon verification. The contract ensures secure and transparent management of digital estates with robust access control and event tracking.

## Features

- **Will Creation**: Create a will, specifying the owner and initializing asset and beneficiary lists.
- **Asset Management**: Register SUI tokens as assets with details like ID, type, and value.
- **Beneficiary Management**: Add or update beneficiaries with share percentages (up to 100% total).
- **Encrypted Key Storage**: Store encrypted keys for assets, accessible only by authorized beneficiaries post-verification.
- **Asset Distribution**: Distribute SUI tokens to beneficiaries based on their share after verification.
- **Verification**: Admins with `AdminCap` can verify wills to enable distribution.
- **Revocation**: Owners can deactivate their will.
- **Access Control**: Restrict modifications to owners and data access to owners/beneficiaries.
- **Event Emission**: Emit events for actions like will creation, asset registration, and verification.

## Contract Structure

### Structs

- **Will**: Core structure for will data:
  - `id`: Unique identifier (UID).
  - `owner`: Address of the will creator.
  - `assets`: Table mapping asset IDs to `Asset` structs.
  - `coin_assets`: Table storing SUI coin objects.
  - `asset_ids`: Vector of registered asset IDs.
  - `beneficiaries`: Vector of `Beneficiary` structs.
  - `encrypted_keys`: Table mapping asset IDs to `EncryptedKey` structs.
  - `is_active`: Boolean indicating if the will is active.
  - `verification_status`: Optional `Verification` struct for admin verification.
- **Asset**: Represents an asset:
  - `asset_id`: Address of the asset.
  - `asset_type`: String (e.g., "SUI_TOKEN").
  - `value`: Asset value (u64).
- **Beneficiary**: Beneficiary details:
  - `beneficiary_address`: Address of the beneficiary.
  - `share_percentage`: Percentage share (u64).
  - `name`: Beneficiary name.
- **EncryptedKey**: Stores encrypted key data:
  - `asset_id`: Associated asset ID.
  - `encrypted_data`: Encrypted key (vector<u8>).
  - `access_granted`: Boolean for access status.
- **Verification**: Tracks verification:
  - `verified_by`: Admin address.
  - `timestamp`: Verification epoch.
- **AdminCap**: Capability for admin actions (contains UID).
- **WillDetails**: View of will details:
  - `owner`, `is_active`, `total_shares`, `verification_status`.
- **Events**: `WillCreated`, `AssetRegistered`, `BeneficiaryAdded`, `KeyStored`, `WillVerified`.

### Key Functions

- **create_will**: Creates and shares a new will.
- **register_asset**: Registers a SUI coin as an asset.
- **add_beneficiary**: Adds a beneficiary with share and name.
- **update_beneficiary_share**: Updates a beneficiary’s share percentage.
- **store_key**: Stores an encrypted key for an asset.
- **access_key**: Retrieves an encrypted key for a beneficiary post-verification.
- **distribute_assets**: Distributes SUI tokens to a beneficiary.
- **verify_will**: Admin verifies the will.
- **revoke_will**: Deactivates the will.
- **get_assets**, **get_beneficiaries**, **get_encrypted_keys**, **get_will_details**: Query functions for authorized users.
- **is_verified**, **is_will_active**: Check will status.

## Usage

### Prerequisites

- Sui blockchain environment (Sui CLI, Move compiler).
- SUI tokens for asset registration.
- Admin address with `AdminCap` for verification.

### Deployment

1. **Compile and Deploy**:
   - Compile using the Sui Move compiler.
   - Deploy via Sui CLI or compatible wallet.
2. **Initialize Admin**:
   - `init` creates an `AdminCap` and transfers it to the sender.

### Example Workflow

1. **Create a Will**:
   - Call `create_will` to initialize a will.
   - Example: `create_will(&mut tx_context)`.
   - Emits: `WillCreated`.
2. **Register Assets**:
   - Use `register_asset` to add SUI tokens.
   - Example: `register_asset(&mut will, coin, &mut tx_context)`.
   - Emits: `AssetRegistered`.
3. **Add Beneficiaries**:
   - Add with `add_beneficiary`.
   - Example: `add_beneficiary(&mut will, beneficiary_addr, 50, "John Doe", &mut tx_context)`.
   - Emits: `BeneficiaryAdded`.
4. **Store Encrypted Keys**:
   - Store keys with `store_key`.
   - Example: `store_key(&mut will, asset_id, encrypted_data, &mut tx_context)`.
   - Emits: `KeyStored`.
5. **Verify Will**:
   - Admin calls `verify_will` with `AdminCap`.
   - Example: `verify_will(&mut will, &admin_cap, &mut tx_context)`.
   - Emits: `WillVerified`.
6. **Distribute Assets**:
   - Beneficiaries call `distribute_assets` post-verification.
   - Example: `distribute_assets(&mut will, &mut tx_context)`.
7. **Revoke Will**:
   - Owner calls `revoke_will` to deactivate.
   - Example: `revoke_will(&mut will, &mut tx_context)`.

### Querying

- Use `get_will_details`, `get_assets`, `get_beneficiaries`, or `get_encrypted_keys` (restricted to owner/beneficiaries).
- Example: `get_will_details(&will, &tx_context)`.

## Security Considerations

- **Access Control**: Only owners can modify wills; beneficiaries access data post-verification.
- **Verification**: Requires `AdminCap` for verification.
- **Share Limits**: Total shares cannot exceed 100%.
- **Asset Safety**: Ensures sufficient asset value before distribution.
- **Encryption**: Keys are encrypted and restricted to verified beneficiaries.

## Error Codes

- `1`: Sender not owner.
- `2`: Will not active.
- `3`: Invalid share percentage or total exceeds 100%.
- `4`: Will not verified or key accessed.
- `5`: Invalid admin capability.
- `6`: Will already verified.
- `7`: Asset or key not found.
- `8`: Sender not owner or beneficiary.
- `9`: Beneficiary not found.
- `10`: Insufficient asset value.

## Events

- `WillCreated`: Will creation.
- `AssetRegistered`: Asset registration.
- `BeneficiaryAdded`: Beneficiary addition.
- `KeyStored`: Key storage.
- `WillVerified`: Will verification.

## Limitations

- Supports only SUI tokens as assets.
- No beneficiary removal (only share updates).
- One-time key access.
- No complex distribution conditions.

## Future Improvements

- Support for additional asset types (NFTs, other tokens).
- Beneficiary removal/update functionality.
- Multi-signature verification.
- Conditional distribution (time/event-based).
- Key rotation/re-encryption.

## Development

- **Language**: Move (Sui dialect).
- **Dependencies**: Sui standard library (`0x1::string`, `0x2::object`, `0x2::table`, `0x2::coin`).
- **Testing**: Use Sui’s testing framework.

## License

MIT License. See `LICENSE` file for details.
