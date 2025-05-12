module crypto_will::will;
use sui::coin::{Self, Coin};
use sui::table::{Self, Table};
use sui::event;
use sui::sui::SUI;
use std::string::{Self, String};

const ENotOwner: u64 = 1;
const EWillInactive: u64 = 2;
const EInvalidShare: u64 = 3;
const ENotVerified: u64 = 4;
const ENotAdmin: u64 = 5;
const EAlreadyVerified: u64 = 6;
const EAssetNotFound: u64 = 7;
const EUnauthorized: u64 = 8;
const EBeneficiaryNotFound: u64 = 9;
const EInsufficientBalance: u64 = 10;

public struct Will has key, store {
  id: UID,
  owner: address,
  assets: Table<address, Asset>,
  coin_assets: Table<address, Coin<SUI>>,
  asset_ids: vector<address>, 
  beneficiaries: vector<Beneficiary>,
  encrypted_keys: Table<address, EncryptedKey>,
  is_active: bool,
  verification_status: Option<Verification>,
}

    public struct Asset has store, copy, drop {
        asset_id: address, 
        asset_type: String,
        value: u64, 
    }

   public struct Beneficiary has store, copy, drop {
        beneficiary_address: address,
        share_percentage: u64,
        name: String,
    }

    /// Stores an encrypted private key with access conditions.
   public struct EncryptedKey has store {
        asset_id: address, 
        encrypted_data: vector<u8>, 
        access_granted: bool,
    }

    /// Tracks verification of the owner's passing (MVP: admin-driven).
   public struct Verification has store, copy, drop {
        verified_by: address, // Admin or oracle
        timestamp: u64,
    }

    /// Admin capability for verification and platform management.
   public struct AdminCap has key {
        id: UID,
    }

   public struct WillDetails has copy, drop {
        owner: address,
        is_active: bool,
        total_shares: u64,
        verification_status: Option<Verification>,
    }

    // === Events ===

   public struct WillCreated has copy, drop {
        will_id: address,
        owner: address,
    }

   public struct AssetRegistered has copy, drop {
        will_id: address,
        asset_id: address,
        asset_type: String,
    }

   public struct BeneficiaryAdded has copy, drop {
        will_id: address,
        beneficiary_address: address,
        share_percentage: u64,
    }

    public struct KeyStored has copy, drop {
        will_id: address,
        asset_id: address,
    }

    public struct WillVerified has copy, drop {
        will_id: address,
        verified_by: address,
    }



    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    public entry fun create_will(ctx: &mut TxContext) {
        let will_id = object::new(ctx);
        let will = Will {
            id: will_id,
            owner: tx_context::sender(ctx),
            assets: table::new(ctx),
            asset_ids: vector::empty(),
            coin_assets: table::new(ctx),
            beneficiaries: vector::empty(),
            encrypted_keys: table::new(ctx),
            is_active: true,
            verification_status: option::none(),
        };
        let will_addr = object::uid_to_address(&will.id);
        transfer::share_object(will);
        event::emit(WillCreated {
            will_id: will_addr,
            owner: tx_context::sender(ctx),
        });
    }

    /// Register a crypto asset in the will.
    public entry fun register_asset(
        will: &mut Will,
        coin: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(will.owner == tx_context::sender(ctx), ENotOwner);
        assert!(will.is_active, EWillInactive);
        let asset_id = object::id_address(&coin);
        let value = coin::value(&coin);
        let asset = Asset {
            asset_id,
            asset_type: string::utf8(b"SUI_TOKEN"),
            value,
        };
        table::add(&mut will.assets, asset_id, asset);
        table::add(&mut will.coin_assets, asset_id, coin);
        vector::push_back(&mut will.asset_ids, asset_id);
        event::emit(AssetRegistered {
            will_id: object::uid_to_address(&will.id),
            asset_id,
            asset_type: string::utf8(b"SUI_TOKEN"),
        });
    }


    /// Add a beneficiary to the will.
    public entry fun add_beneficiary(
        will: &mut Will,
        beneficiary_address: address,
        share_percentage: u64,
        name: String,
        ctx: &mut TxContext
    ) {
        assert!(will.owner == tx_context::sender(ctx), ENotOwner);
        assert!(will.is_active, EWillInactive);
        assert!(share_percentage <= 100, EInvalidShare);
        let total_shares = calculate_total_shares(&will.beneficiaries);
        assert!(total_shares + share_percentage <= 100, EInvalidShare);
        let beneficiary = Beneficiary {
            beneficiary_address,
            share_percentage,
            name,
        };
        vector::push_back(&mut will.beneficiaries, beneficiary);
        event::emit(BeneficiaryAdded {
            will_id: object::uid_to_address(&will.id),
            beneficiary_address,
            share_percentage,
        });
    }

    /// Store an encrypted private key for an asset.
    public entry fun store_key(
        will: &mut Will,
        asset_id: address,
        encrypted_data: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(will.owner == tx_context::sender(ctx), ENotOwner);
        assert!(will.is_active, EWillInactive);
        assert!(table::contains(&will.assets, asset_id), EAssetNotFound);
        let encrypted_key = EncryptedKey {
            asset_id,
            encrypted_data,
            access_granted: false,
        };
        table::add(&mut will.encrypted_keys, asset_id, encrypted_key);
        event::emit(KeyStored {
            will_id: object::uid_to_address(&will.id),
            asset_id,
        });
    }

    /// Verify the owner's passing (admin-only for MVP).
    public entry fun verify_will(
        will: &mut Will,
        admin: &AdminCap,
        ctx: &mut TxContext
    ) {
        assert!(option::is_none(&will.verification_status), EAlreadyVerified);
        let admin_address = tx_context::sender(ctx);
        assert!(object::uid_to_address(&admin.id) != @0x0, ENotAdmin);
        will.verification_status = option::some(Verification {
            verified_by: admin_address,
            timestamp: tx_context::epoch(ctx),
        });
        event::emit(WillVerified {
            will_id: object::uid_to_address(&will.id),
            verified_by: admin_address,
        });
    }

    /// Access an encrypted private key after verification.
    public fun access_key(
        will: &Will,
        asset_id: address,
        ctx: &mut TxContext
    ): vector<u8> {
        assert!(option::is_some(&will.verification_status), ENotVerified);
        assert!(table::contains(&will.encrypted_keys, asset_id), EAssetNotFound);
        let beneficiary_address = tx_context::sender(ctx);
        assert!(is_beneficiary(&will.beneficiaries, beneficiary_address), EUnauthorized);
        let key = table::borrow(&will.encrypted_keys, asset_id);
        assert!(!key.access_granted, ENotVerified);
        key.encrypted_data
    }

    /// Transfer assets to beneficiaries after verification (simplified for MVP).
    public entry fun distribute_assets(
        will: &mut Will,
        ctx: &mut TxContext
    ) {
        assert!(option::is_some(&will.verification_status), ENotVerified);
        assert!(will.is_active, EWillInactive);
        let beneficiary_address = tx_context::sender(ctx);
        assert!(is_beneficiary(&will.beneficiaries, beneficiary_address), EUnauthorized);
        // Find the beneficiary
        let beneficiary = find_beneficiary(&will.beneficiaries, beneficiary_address);
        let mut i = 0;
        while (i < vector::length(&will.asset_ids)) {
            let asset_id = *vector::borrow(&will.asset_ids, i);
            let asset = table::borrow(&will.assets, asset_id);
            if (asset.asset_type == string::utf8(b"SUI_TOKEN")) {
                let amount = (asset.value * beneficiary.share_percentage) / 100;
                if (amount > 0) {
                    // Get the Coin<SUI> from coin_assets
                    let coin = table::borrow_mut(&mut will.coin_assets, asset_id);
                    assert!(coin::value(coin) >= amount, EInsufficientBalance);
                    let split_coin = coin::split<SUI>(coin, amount, ctx);
                    transfer::public_transfer(split_coin, beneficiary_address);
                    // Update asset metadata
                    let asset_mut = table::borrow_mut(&mut will.assets, asset_id);
                    asset_mut.value = asset_mut.value - amount;
                };
            };
            i = i + 1;
        };
        will.is_active = false; // Mark will as executed
    }


    /// Update a beneficiary’s share.
    public entry fun update_beneficiary_share(
        will: &mut Will,
        beneficiary_address: address,
        new_share_percentage: u64,
        ctx: &mut TxContext
    ) {
        assert!(will.owner == tx_context::sender(ctx), ENotOwner);
        assert!(will.is_active, EWillInactive);
        assert!(new_share_percentage <= 100, EInvalidShare);
        assert!(is_beneficiary(&will.beneficiaries, beneficiary_address), EBeneficiaryNotFound);
        let total_shares = calculate_total_shares(&will.beneficiaries);
        let mut i = 0;
        let len = vector::length(&will.beneficiaries);
        let mut old_share = 0;
        while (i < len) {
            let beneficiary = vector::borrow_mut(&mut will.beneficiaries, i);
            if (beneficiary.beneficiary_address == beneficiary_address) {
                old_share = beneficiary.share_percentage;
                beneficiary.share_percentage = new_share_percentage;
                break
            };
            i = i + 1;
        };
        assert!(total_shares - old_share + new_share_percentage <= 100, EInvalidShare);
    }

    /// Revoke the will.
    public entry fun revoke_will(will: &mut Will, ctx: &mut TxContext) {
        assert!(will.owner == tx_context::sender(ctx), ENotOwner);
        assert!(will.is_active, EWillInactive);
        will.is_active = false;
    }

    // === Query Functions ===

    /// Get the list of assets in the will.
    public fun get_assets(will: &Will, ctx: &TxContext): vector<Asset> {
        let sender = tx_context::sender(ctx);
        assert!(
            will.owner == sender || is_beneficiary(&will.beneficiaries, sender),
            EUnauthorized
        );
        let mut result = vector::empty<Asset>();
        let mut i = 0;
        while (i < vector::length(&will.asset_ids)) {
            let asset_id = *vector::borrow(&will.asset_ids, i);
            let asset = table::borrow(&will.assets, asset_id);
            vector::push_back(&mut result, *asset);
            i = i + 1;
        };
        result
    }

    /// Get the list of beneficiaries in the will.
    public fun get_beneficiaries(will: &Will, ctx: &TxContext): vector<Beneficiary> {
        let sender = tx_context::sender(ctx);
        assert!(
            will.owner == sender || is_beneficiary(&will.beneficiaries, sender),
            EUnauthorized
        );
        will.beneficiaries
    }

    /// Get comprehensive will details.
    public fun get_will_details(will: &Will, ctx: &TxContext): WillDetails {
        let sender = tx_context::sender(ctx);
        // Allow owner or beneficiaries to view details
        assert!(
            will.owner == sender || is_beneficiary(&will.beneficiaries, sender),
            EUnauthorized
        );
        WillDetails {
            owner: will.owner,
            is_active: will.is_active,
            total_shares: calculate_total_shares(&will.beneficiaries),
            verification_status: will.verification_status,
        }
    }

    /// Get the list of encrypted keys and their associated asset IDs.
    public fun get_encrypted_keys(will: &Will, ctx: &TxContext): vector<address> {
        let sender = tx_context::sender(ctx);
        assert!(will.owner == sender || option::is_some(&will.verification_status), EUnauthorized);
        let mut result = vector::empty<address>();
        let mut i = 0;
        while (i < vector::length(&will.asset_ids)) {
            let asset_id = *vector::borrow(&will.asset_ids, i);
            if (table::contains(&will.encrypted_keys, asset_id)) {
                vector::push_back(&mut result, asset_id);
            };
            i = i + 1;
        };
        result
    }

     public fun is_will_active(will: &Will): bool {
        will.is_active    
    }

    public fun is_verified(will: &Will): bool {
        option::is_some(&will.verification_status)    
    }



    fun calculate_total_shares(beneficiaries: &vector<Beneficiary>): u64 {
        let mut total = 0;
        let mut i = 0;
        let len = vector::length(beneficiaries);
        while (i < len) {
            let beneficiary = vector::borrow(beneficiaries, i);
            total = total + beneficiary.share_percentage;
            i = i + 1;
        };
        total
    }

    fun is_beneficiary(beneficiaries: &vector<Beneficiary>, address: address): bool {
        let mut i = 0;
        let len = vector::length(beneficiaries);
        while (i < len) {
            let beneficiary = vector::borrow(beneficiaries, i);
            if (beneficiary.beneficiary_address == address) {
                return true
            };
            i = i + 1;
        };
        false
    }

    fun find_beneficiary(beneficiaries: &vector<Beneficiary>, address: address): Beneficiary {
        let mut i = 0;
        let len = vector::length(beneficiaries);
        while (i < len) {
            let beneficiary = vector::borrow(beneficiaries, i);
            if (beneficiary.beneficiary_address == address) {
                return *beneficiary
            };
            i = i + 1;
        };
        abort EBeneficiaryNotFound
    }

#[test_only]
public fun create_admin_cap_for_testing(ctx: &mut TxContext) {
    let admin_cap = AdminCap { id: object::new(ctx) };
    transfer::transfer(admin_cap, tx_context::sender(ctx));
}
   
