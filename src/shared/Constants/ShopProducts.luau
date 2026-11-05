--!strict
-- Expected prices document the Dashboard snapshot only; managed pricing is authoritative.
return table.freeze({
    WingsGamePassId = 2021642550,
    IceGunGamePassId = 2022020489,
    Cash2x10Minutes = table.freeze({
        ProductId = 3728323243,
        DurationSeconds = 600,
        ExpectedPriceRobux = 19,
    }),
    Cash2x30Minutes = table.freeze({
        ProductId = 3728323462,
        DurationSeconds = 1800,
        ExpectedPriceRobux = 29,
    }),
})
