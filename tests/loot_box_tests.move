/// Module: loot_box_system::loot_box_tests
/// 
/// Test suite for the loot box system
#[test_only]
module loot_box::loot_box_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::random::{Self, Random};
    use sui::test_utils;

    use loot_box::loot_box::{
        Self,
        GameConfig,
        AdminCap,
        LootBox,
        GameItem,
        EInsufficientPayment,
        EInvalidWeights,
        set_pity_for_test,
    };

    // ===== Test Constants =====
    const ADMIN: address = @0xAD;
    const PLAYER1: address = @0x1;
    const PLAYER2: address = @0x2;

    // ===== Helper Functions =====

    /// Initialize test scenario with game setup
    fun setup_game(scenario: &mut Scenario) {
        ts::begin(scenario, ADMIN);
        loot_box::init_game<SUI>(ts::ctx(scenario));
        ts::end(scenario);
    }

    /// Create a test coin with specified amount
    fun mint_test_coin(scenario: &mut Scenario, amount: u64): Coin<SUI> {
        ts::begin(scenario, ADMIN);
        let coin = coin::mint<SUI>(amount, ts::ctx(scenario));
        ts::end(scenario);
        coin
    }

    // ===== Test Cases =====

    #[test]
    fun test_init_game() {
        let mut scenario = ts::new();

        setup_game(&mut scenario);

        let config: &GameConfig<SUI> = ts::borrow_shared(&scenario);
        let admin: AdminCap = ts::take_from_address(&scenario, ADMIN);

        let (c, r, e, l) = loot_box::get_rarity_weights(config);
        assert!(c == 60, 0);
        assert!(r == 25, 1);
        assert!(e == 12, 2);
        assert!(l == 3, 3);

        let price = loot_box::get_loot_box_price(config);
        assert!(price == 100, 4);

        let _ = admin;
        ts::destroy(scenario);
    }

    #[test]
    fun test_purchase_loot_box() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        let payment = coin::mint<SUI>(100, ts::ctx(&mut scenario));
        let loot_box: LootBox =
            loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        let LootBox { id: _ } = loot_box;

        ts::end(&mut scenario);
        ts::destroy(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EInsufficientPayment)]
    fun test_purchase_insufficient_payment() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        let payment = coin::mint<SUI>(50, ts::ctx(&mut scenario));
        loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        ts::end(&mut scenario);
    }

    #[test]
    fun test_open_loot_box() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        let payment = coin::mint<SUI>(100, ts::ctx(&mut scenario));
        let loot_box =
            loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        let rand = random::new(ts::ctx(&mut scenario));

        loot_box::open_loot_box(config, loot_box, &rand, ts::ctx(&mut scenario));

        let item: GameItem = ts::take_from_sender(&mut scenario);
        let (_name, rarity, power) = loot_box::get_item_stats(&item);

        assert!(rarity <= 3, 10);
        assert!(power >= 1, 11);

        ts::end(&mut scenario);
        ts::destroy(scenario);
    }

    #[test]
    fun test_get_item_stats() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        let payment = coin::mint<SUI>(100, ts::ctx(&mut scenario));
        let loot_box =
            loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        let rand = random::new(ts::ctx(&mut scenario));
        loot_box::open_loot_box(config, loot_box, &rand, ts::ctx(&mut scenario));

        let item: GameItem = ts::take_from_sender(&mut scenario);
        let (_name, rarity, power) = loot_box::get_item_stats(&item);

        assert!(rarity <= 3, 20);
        assert!(power > 0, 21);

        ts::end(&mut scenario);
        ts::destroy(scenario);
    }

    #[test]
    fun test_transfer_item() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        let payment = coin::mint<SUI>(100, ts::ctx(&mut scenario));
        let loot_box =
            loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        let rand = random::new(ts::ctx(&mut scenario));
        loot_box::open_loot_box(config, loot_box, &rand, ts::ctx(&mut scenario));

        let item: GameItem = ts::take_from_sender(&mut scenario);
        loot_box::transfer_item(item, PLAYER2);

        ts::end(&mut scenario);

        let _received: GameItem =
            ts::take_from_address(&scenario, PLAYER2);

        ts::destroy(scenario);
    }

    #[test]
    fun test_burn_item() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        let payment = coin::mint<SUI>(100, ts::ctx(&mut scenario));
        let loot_box =
            loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        let rand = random::new(ts::ctx(&mut scenario));
        loot_box::open_loot_box(config, loot_box, &rand, ts::ctx(&mut scenario));

        let item: GameItem = ts::take_from_sender(&mut scenario);
        loot_box::burn_item(item);

        ts::end(&mut scenario);
        ts::destroy(scenario);
    }

    #[test]
    fun test_pity_system() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        ts::begin(&mut scenario, PLAYER1);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        // Force pity threshold for PLAYER1
        set_pity_for_test(config, PLAYER1, 30);

        let payment = coin::mint<SUI>(100, ts::ctx(&mut scenario));
        let loot_box =
            loot_box::purchase_loot_box(config, payment, ts::ctx(&mut scenario));

        let rand = random::new(ts::ctx(&mut scenario));
        loot_box::open_loot_box(config, loot_box, &rand, ts::ctx(&mut scenario));

        let item: GameItem = ts::take_from_sender(&mut scenario);
        let (_name, rarity, _power) = loot_box::get_item_stats(&item);

        // Legendary should be forced when pity threshold is reached
        assert!(rarity == 3, 40);

        ts::end(&mut scenario);
        ts::destroy(scenario);
    }

    #[test]
    fun test_update_rarity_weights() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        let admin: AdminCap = ts::take_from_address(&scenario, ADMIN);

        ts::begin(&mut scenario, ADMIN);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        loot_box::update_rarity_weights(
            &admin,
            config,
            50,
            30,
            15,
            5
        );

        let (c, r, e, l) = loot_box::get_rarity_weights(config);
        assert!(c == 50, 30);
        assert!(r == 30, 31);
        assert!(e == 15, 32);
        assert!(l == 5, 33);

        ts::end(&mut scenario);
        ts::destroy(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EInvalidWeights)]
    fun test_update_weights_invalid_sum() {
        let mut scenario = ts::new();
        setup_game(&mut scenario);

        let admin: AdminCap = ts::take_from_address(&scenario, ADMIN);

        ts::begin(&mut scenario, ADMIN);

        let mut config: &mut GameConfig<SUI> =
            ts::borrow_shared_mut(&mut scenario);

        loot_box::update_rarity_weights(
            &admin,
            config,
            40,
            30,
            20,
            20 // sum = 110 
        );

        ts::end(&mut scenario);
    }
}