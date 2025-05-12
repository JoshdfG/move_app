#[test_only]
module crypto_will::crypto_will_tests;

use crypto_will::will::{
    Self, Will, AdminCap};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::test_scenario::{Self, Scenario};
use std::string;

const OWNER: address = @0xA;
const ADMIN: address = @0xB;
const BENEFICIARY1: address = @0xC;
const BENEFICIARY2: address = @0xD;
const NON_BENEFICIARY: address = @0xE;

fun create_test_will(scenario: &mut Scenario) {
    test_scenario::next_tx(scenario, OWNER);
    {
        let ctx = test_scenario::ctx(scenario);
        will::create_will(ctx);
    };
    test_scenario::next_tx(scenario, OWNER);
}

fun mint_sui_coin(scenario: &mut Scenario, amount: u64, recipient: address): Coin<SUI> {
    test_scenario::next_tx(scenario, recipient);
    {
        let ctx = test_scenario::ctx(scenario);
        let coin = coin::mint_for_testing<SUI>(amount, ctx);
        transfer::public_transfer(coin, recipient);
    };
    test_scenario::next_tx(scenario, recipient);
    test_scenario::take_from_sender<Coin<SUI>>(scenario)
}

// Helper function to create an AdminCap for testing
fun create_admin_cap(scenario: &mut Scenario) {
    test_scenario::next_tx(scenario, ADMIN);
    {
        let ctx = test_scenario::ctx(scenario);
        will::create_admin_cap_for_testing(ctx);
    };
    test_scenario::next_tx(scenario, ADMIN);
}

#[test]
fun test_create_will() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let _details = will::get_will_details(&will, test_scenario::ctx(&mut scenario));
        assert!(will::is_will_active(&will), 0);
        assert!(!will::is_verified(&will), 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_register_asset() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin_amount = 1000;
    let coin = mint_sui_coin(&mut scenario, coin_amount, OWNER);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let assets = will::get_assets(&will, test_scenario::ctx(&mut scenario));
        assert!(vector::length(&assets) == 1, 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::ENotOwner)]
fun test_register_asset_not_owner() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, NON_BENEFICIARY);
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EWillInactive)]
fun test_register_asset_inactive_will() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::revoke_will(&mut will, ctx);
        test_scenario::return_shared(will);
    };
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_add_beneficiary() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let beneficiaries = will::get_beneficiaries(&will, test_scenario::ctx(&mut scenario));
        assert!(vector::length(&beneficiaries) == 1, 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EInvalidShare)]
fun test_add_beneficiary_invalid_share() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 101, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EInvalidShare)]
fun test_add_beneficiary_exceed_shares() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 80, string::utf8(b"Alice"), ctx);
        will::add_beneficiary(&mut will, BENEFICIARY2, 30, string::utf8(b"Bob"), ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_store_key() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    let asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, asset_id, encrypted_data, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let keys = will::get_encrypted_keys(&will, test_scenario::ctx(&mut scenario));
        assert!(vector::length(&keys) == 1, 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EAssetNotFound)]
fun test_store_key_asset_not_found() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, @0xF, encrypted_data, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_verify_will() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    create_admin_cap(&mut scenario); 
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::verify_will(&mut will, &admin_cap, ctx);
        test_scenario::return_shared(will);
        test_scenario::return_to_sender(&scenario, admin_cap);
    };
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        assert!(will::is_verified(&will), 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EAlreadyVerified)]
fun test_verify_will_already_verified() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    create_admin_cap(&mut scenario); 
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::verify_will(&mut will, &admin_cap, ctx);
        will::verify_will(&mut will, &admin_cap, ctx); // Should fail
        test_scenario::return_shared(will);
        test_scenario::return_to_sender(&scenario, admin_cap);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_access_key() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    let asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, asset_id, encrypted_data, ctx);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    create_admin_cap(&mut scenario); 
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::verify_will(&mut will, &admin_cap, ctx);
        test_scenario::return_shared(will);
        test_scenario::return_to_sender(&scenario, admin_cap);
    };
    test_scenario::next_tx(&mut scenario, BENEFICIARY1);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        let key_data = will::access_key(&will, asset_id, ctx);
        assert!(key_data == vector[1u8, 2u8, 3u8], 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::ENotVerified)]
fun test_access_key_not_verified() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    let asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, asset_id, encrypted_data, ctx);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, BENEFICIARY1);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::access_key(&will, asset_id, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EUnauthorized)]
fun test_access_key_unauthorized() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    let asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, asset_id, encrypted_data, ctx);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    create_admin_cap(&mut scenario); 
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::verify_will(&mut will, &admin_cap, ctx);
        test_scenario::return_shared(will);
        test_scenario::return_to_sender(&scenario, admin_cap);
    };
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::access_key(&will, asset_id, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_distribute_assets() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin_amount = 1000;
    let coin = mint_sui_coin(&mut scenario, coin_amount, OWNER);
    let _asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    create_admin_cap(&mut scenario);
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::verify_will(&mut will, &admin_cap, ctx);
        test_scenario::return_shared(will);
        test_scenario::return_to_sender(&scenario, admin_cap);
    };
    test_scenario::next_tx(&mut scenario, BENEFICIARY1);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::distribute_assets(&mut will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, BENEFICIARY1);
    {
        let coin = test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        assert!(coin::value(&coin) == 500, 0); // 50% of 1000
        let will = test_scenario::take_shared<Will>(&scenario);
        assert!(!will::is_will_active(&will), 0);
        test_scenario::return_to_sender(&scenario, coin);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

// Test distributing assets before verification (should fail)
#[test, expected_failure(abort_code = ::crypto_will::will::ENotVerified)]
fun test_distribute_assets_not_verified() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, BENEFICIARY1);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::distribute_assets(&mut will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EUnauthorized)]
fun test_distribute_assets_unauthorized() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    create_admin_cap(&mut scenario);    
    test_scenario::next_tx(&mut scenario, ADMIN);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::verify_will(&mut will, &admin_cap, ctx);
        test_scenario::return_shared(will);
        test_scenario::return_to_sender(&scenario, admin_cap);
    };
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::distribute_assets(&mut will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_update_beneficiary_share() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        will::update_beneficiary_share(&mut will, BENEFICIARY1, 30, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EBeneficiaryNotFound)]
fun test_update_beneficiary_share_not_found() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::update_beneficiary_share(&mut will, BENEFICIARY1, 30, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::ENotOwner)]
fun test_update_beneficiary_share_not_owner() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::update_beneficiary_share(&mut will, BENEFICIARY1, 30, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_revoke_will() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::revoke_will(&mut will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        assert!(!will::is_will_active(&will), 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::ENotOwner)]
fun test_revoke_will_not_owner() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::revoke_will(&mut will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_get_will_details() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        let _details = will::get_will_details(&will, ctx);
        assert!(will::is_will_active(&will), 0);
        assert!(!will::is_verified(&will), 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EUnauthorized)]
fun test_get_will_details_unauthorized() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::get_will_details(&will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_get_beneficiaries() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::add_beneficiary(&mut will, BENEFICIARY1, 50, string::utf8(b"Alice"), ctx);
        let beneficiaries = will::get_beneficiaries(&will, ctx);
        assert!(vector::length(&beneficiaries) == 1, 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EUnauthorized)]
fun test_get_beneficiaries_unauthorized() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::get_beneficiaries(&will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_get_assets() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        let assets = will::get_assets(&will, ctx);
        assert!(vector::length(&assets) == 1, 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EUnauthorized)]
fun test_get_assets_unauthorized() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::get_assets(&will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test]
fun test_get_encrypted_keys() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    let asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, asset_id, encrypted_data, ctx);
        let keys = will::get_encrypted_keys(&will, ctx);
        assert!(vector::length(&keys) == 1, 0);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::crypto_will::will::EUnauthorized)]
fun test_get_encrypted_keys_unauthorized() {
    let mut scenario = test_scenario::begin(OWNER);
    create_test_will(&mut scenario);
    let coin = mint_sui_coin(&mut scenario, 1000, OWNER);
    let asset_id = object::id_address(&coin);
    test_scenario::next_tx(&mut scenario, OWNER);
    {
        let mut will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::register_asset(&mut will, coin, ctx);
        let encrypted_data = vector[1u8, 2u8, 3u8];
        will::store_key(&mut will, asset_id, encrypted_data, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::next_tx(&mut scenario, NON_BENEFICIARY);
    {
        let will = test_scenario::take_shared<Will>(&scenario);
        let ctx = test_scenario::ctx(&mut scenario);
        will::get_encrypted_keys(&will, ctx);
        test_scenario::return_shared(will);
    };
    test_scenario::end(scenario);
}

