// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module sui_fantasy::fantasy_wallet {
    // use std::debug;
    use std::option;
    use std::string::{Self, String};

    use sui::dynamic_field as dfield;
    use sui::object::{Self, UID};
    use sui::package;
    use sui::transfer::{Self};
    use sui::tx_context::{Self, TxContext};

    use oracle::data::Data;
    use oracle::decimal_value::{Self, DecimalValue};
    use oracle::simple_oracle::{Self, SimpleOracle};
    use sui::math;

    /// For when someone tries to claim an NFT again.
    const EAlreadyRegistered: u64 = 0;

    /// For when someone tries to swap bigger amount that owns.
    const EInsufficientAmount: u64 = 1;

    // ======== Types =========

    struct FantasyWallet has key {
        id: UID,
        sui: DecimalValue,
        eth: DecimalValue,
        usdt: DecimalValue,
        btc: DecimalValue,
        usd: DecimalValue,
    }

    struct Registry has key { id: UID }

    /// Belongs to the creator of the game. Has store, which
    /// allows building something on top of it (ie shared object with
    /// multi-access policy for managers).
    struct AdminCap has key, store { id: UID }

    /// One Time Witness to create the `Publisher`.
    struct FANTASY_WALLET has drop {}

    // ======== Functions =========

    /// Module initializer. Uses One Time Witness to create Publisher and transfer it to sender.
    fun init(otw: FANTASY_WALLET, ctx: &mut TxContext) {
        package::claim_and_keep(otw, ctx);
        let cap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(cap, tx_context::sender(ctx));
        transfer::share_object(Registry { id: object::new(ctx) });
    }


    // ======= Mint/Register Functions =======

    /// Get a "FantasyWallet". Can only be called once.
    /// Aborts when trying to be called again.
    public fun get_fantasy_wallet(
        registry: &mut Registry, 
        ctx: &mut TxContext
    ): FantasyWallet {
        let sender = tx_context::sender(ctx);

        assert!(
            !dfield::exists_with_type<address, bool>(&registry.id, sender), 
            EAlreadyRegistered
        );

        dfield::add<address, bool>(&mut registry.id, sender, true);
        mint(ctx)
    }

    public fun mint_and_transfer_fantasy_wallet(
        registry: &mut Registry, 
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        assert!(
            !dfield::exists_with_type<address, bool>(&registry.id, sender), 
            EAlreadyRegistered
        );

        dfield::add<address, bool>(&mut registry.id, sender, true);
        mint_and_transfer(ctx);
    }

    fun mint(
        ctx: &mut TxContext
    ): FantasyWallet {
        FantasyWallet {
            id: object::new(ctx),

            sui: decimal_value::new(1_000_000, 4),
            eth: decimal_value::new(1_000_000, 4),
            usdt: decimal_value::new(1_000_000, 4),
            btc: decimal_value::new(1_000_000, 4),
            usd: decimal_value::new(1_000_000, 4),
        }
    }

    fun mint_and_transfer(
        ctx: &mut TxContext
    ) {
        transfer::transfer(
            mint(ctx),
            tx_context::sender(ctx)
        );
    }

    // ======= Fantasy Wallet Functions =======

    public fun swap(
        fantasy_wallet: &mut FantasyWallet,
        // oracle: &SimpleOracle,
        coinA: String,
        coinB: String,
        amount: u64
    ) {
        // let rate = get_rate(oracle, coinA, coinB);
        // let rate = decimal_value::new(500, 6);

        let coinA_decimal_value = get_coin_decimal_value(fantasy_wallet, coinA);
        let coinB_decimal_value = get_coin_decimal_value(fantasy_wallet, coinB);

        assert!(decimal_value::value(&coinA_decimal_value) >= amount, EInsufficientAmount);

        let rate = decimal_value::new(500000, 6);
        let rate_decimals = decimal_value::decimal(&rate);

        if (decimal_value::decimal(&coinA_decimal_value) > rate_decimals) {
            rate = decimal_value::new(
                decimal_value::value(&rate) * (math::pow(10, decimal_value::decimal(&coinA_decimal_value) - rate_decimals) as u64),
                decimal_value::decimal(&rate) + (decimal_value::decimal(&coinA_decimal_value) - rate_decimals)
            );
        } else if (decimal_value::decimal(&coinA_decimal_value) < rate_decimals) {
            rate = decimal_value::new(
                decimal_value::value(&rate) / (math::pow(10, rate_decimals - decimal_value::decimal(&coinA_decimal_value)) as u64),
                decimal_value::decimal(&rate) - (rate_decimals - decimal_value::decimal(&coinA_decimal_value))
            );
        };

        let coinA_updated_value = subtract(&mut coinA_decimal_value, &rate);
        set_coin_amount(fantasy_wallet, coinA, coinA_updated_value);

        let coinB_updated_value = multiply(&mut coinB_decimal_value, &rate);
        set_coin_amount(fantasy_wallet, coinB, coinB_updated_value);
    }

    public fun get_rate(
        oracle: &SimpleOracle,
        _coinA: String,
        _coinB: String
    ): Data<DecimalValue> {
        // let ticker = coinA;
        // string::append(&mut ticker, string::utf8(b"/"));
        // string::append(&mut ticker, coinB);
        // // HACK
        // string::append(&mut ticker, string::utf8(b"-gate"));
        
        let single_data = simple_oracle::get_latest_data<DecimalValue>(oracle, string::utf8(b"usdc/usd-gate"));
        option::destroy_some(single_data)
    }

    fun get_coin_decimal_value(
        fantasy_wallet: &mut FantasyWallet,
        coin: String,
    ): DecimalValue {
        if (string::bytes(&coin) == string::bytes(&string::utf8(b"sui"))) {
            fantasy_wallet.sui
        }
        // else if (string::bytes(&coin) == string::bytes(&string::utf8(b"eth"))) {
        else {
            fantasy_wallet.eth
        }
    }

    fun set_coin_amount(
        fantasy_wallet: &mut FantasyWallet,
        coin: String,
        decimal_value: DecimalValue
    ) {
        if (string::bytes(&coin) == string::bytes(&string::utf8(b"sui"))) {
            fantasy_wallet.sui = decimal_value;
        }
        // else if (string::bytes(&coin) == string::bytes(&string::utf8(b"eth"))) {
        else {
            fantasy_wallet.eth = decimal_value;
        }
    }

    public fun add(
        self: &mut DecimalValue, 
        other: &DecimalValue
    ): DecimalValue {
        if (decimal_value::decimal(self) != decimal_value::decimal(other)) {
            // Return an error or convert one of the values to have the same number of decimals as the other
        };
        let new_value = decimal_value::value(self) + decimal_value::value(other);
        decimal_value::new(new_value, decimal_value::decimal(self))
    }

    public fun subtract(
        self: &mut DecimalValue, 
        other: &DecimalValue
    ): DecimalValue {
        if (decimal_value::decimal(self) != decimal_value::decimal(other)) {
            // Return an error or convert one of the values to have the same number of decimals as the other
        };
        let new_value = decimal_value::value(self) - decimal_value::value(other);
        decimal_value::new(new_value, decimal_value::decimal(self))
    }

    public fun multiply(
        self: &mut DecimalValue, 
        other: &DecimalValue
    ): DecimalValue {
        if (decimal_value::decimal(self) != decimal_value::decimal(other)) {
            // Return an error or convert one of the values to have the same number of decimals as the other
        };
        let new_value = decimal_value::value(self) * decimal_value::value(other);
        decimal_value::new(new_value, decimal_value::decimal(self))
    }

    public fun sui(self: &FantasyWallet): DecimalValue { self.sui }
    public fun eth(self: &FantasyWallet): DecimalValue { self.eth }

    #[test_only]
    public fun mint_for_testing(ctx: &mut TxContext): FantasyWallet {
        FantasyWallet {
            id: object::new(ctx),
            sui: decimal_value::new(1_000_000, 4),
            eth: decimal_value::new(1_000_000, 4),
            usdt: decimal_value::new(1_000_000, 4),
            btc: decimal_value::new(1_000_000, 4),
            usd: decimal_value::new(1_000_000, 4),
        }
    }

    #[test_only]
    public fun burn_for_testing(fantasy_wallet: FantasyWallet) {
        let FantasyWallet {
            id,
            sui: _,
            eth: _,
            usdt: _,
            btc: _,
            usd: _,
        } = fantasy_wallet;
        object::delete(id)
    }

    #[test_only]
    public fun swap_for_testing(
        fantasy_wallet: &mut FantasyWallet,
        coinA: String,
        coinB: String,
        amount: u64
    ) {
        let coinA_decimal_value = get_coin_decimal_value(fantasy_wallet, coinA);
        let coinB_decimal_value = get_coin_decimal_value(fantasy_wallet, coinB);

        assert!(decimal_value::value(&coinA_decimal_value) >= amount, EInsufficientAmount);

        let rate = decimal_value::new(500000, 6);
        let rate_decimals = decimal_value::decimal(&rate);

        if (decimal_value::decimal(&coinA_decimal_value) > rate_decimals) {
            rate = decimal_value::new(
                decimal_value::value(&rate) * (math::pow(10, decimal_value::decimal(&coinA_decimal_value) - rate_decimals) as u64),
                decimal_value::decimal(&rate) + (decimal_value::decimal(&coinA_decimal_value) - rate_decimals)
            );
        } else if (decimal_value::decimal(&coinA_decimal_value) < rate_decimals) {
            rate = decimal_value::new(
                decimal_value::value(&rate) / (math::pow(10, rate_decimals - decimal_value::decimal(&coinA_decimal_value)) as u64),
                decimal_value::decimal(&rate) - (rate_decimals - decimal_value::decimal(&coinA_decimal_value))
            );
        };

        let coinA_updated_value = subtract(&mut coinA_decimal_value, &rate);
        set_coin_amount(fantasy_wallet, coinA, coinA_updated_value);

        let coinB_updated_value = multiply(&mut coinB_decimal_value, &rate);
        set_coin_amount(fantasy_wallet, coinB, coinB_updated_value);
    }
}
