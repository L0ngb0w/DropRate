local lu = require('luaunit')
local Mock = require('test.mock.Mock')
local Spy = require('test.mock.Spy')
local ValueMatcher = require('test.mock.ValueMatcher')

RegisterEvent = Mock()
RegisterEvent:whenCalled{with={ValueMatcher.any, 'ADDON_LOADED'}}

SetScript = Mock()
SetScript:whenCalled{with={ValueMatcher.any, 'OnEvent', ValueMatcher.any}}

Frame = {}
Frame['RegisterEvent'] = RegisterEvent
Frame['SetScript'] = SetScript

CreateFrame = Mock()
CreateFrame:whenCalled{with={'Frame'}, thenReturn={Frame}}

GetItemQualityColor = Mock()
GetItemQualityColor:whenCalled{with={ValueMatcher.any}, thenReturn={0, 0, 0}}

HookScript = Mock()
HookScript:whenCalled{with={ValueMatcher.any, 'OnTooltipSetUnit', ValueMatcher.any}}

GameTooltip = {}
GameTooltip['HookScript'] = HookScript

SlashCmdList = {}

require('DropRate')

function testDropRate_UpgradeUnitTableFrom1To2_UpgradeUnitTable_TableUpgraded()
	local old = {
		["_version"] = 1,
		["A"] = {
			["AA"] = { -- Unit in first, not in second
				["count"] = 123,
				["items"] = {
					["AAA"] = {
						["quantity"] = 1,
						["count"] = 2,
						["quality"] = 1
					},
					["AAB"] = { -- Item does not have quality
						["quantity"] = 1,
						["count"] = 1,
					}
				}
			},
			["AB"] = { -- Unit in first and in second
				["count"] = 234,
				["items"] = {
					["ABA"] = { -- Item in first, not in second
						["quantity"] = 4,
						["count"] = 5,
						["quality"] = 1
					},
					["ABB"] = { -- Item in first and in second
						["quantity"] = 7,
						["count"] = 8,
						["quality"] = 1
					}
				}
			},
			["AC"] = { -- Unit empty in first, not empty in second
				["count"] = 345,
				["items"] = {}
			},
			["AD"] = { -- Unit not empty in first, is empty in second
				["count"] = 678,
				["items"] = {
					["ADA"] = {
						["quantity"] = 19,
						["count"] = 20,
						["quality"] = 1
					}
				}
			}
		},
		["B"] = {
			["AB"] = { -- Unit in first and in second
				["count"] = 456,
				["items"] = {
					["ABB"] = { -- Item in first and in second
						["quantity"] = 10,
						["count"] = 11,
						["quality"] = 1
					},
					["ABC"] = { -- Item not in first, is in second
						["quantity"] = 13,
						["count"] = 14,
						["quality"] = 1
					}
				}
			},
			["AC"] = { -- Unit empty in first, not empty in second
				["count"] = 567,
				["items"] = {
					["ACA"] = {
						["quantity"] = 16,
						["count"] = 17,
						["quality"] = 1
					}
				}
			},
			["AD"] = { -- Unit not empty in first, is empty in second
				["count"] = 789,
				["items"] = {}
			},
			["BA"] = { -- Unit not in first, is in second
				["count"] = 890,
				["items"] = {
					["BAA"] = {
						["quantity"] = 22,
						["count"] = 23,
						["quality"] = 1
					}
				}
			}
		}
	}

	local expected = {
		["_version"] = 2,
		["AA"] = { -- Unit in first, not in second
			["count"] = 123,
			["items"] = {
				["AAA"] = {
					["quantity"] = 1,
					["count"] = 2,
					["quality"] = 1
				},
				["AAB"] = { -- Item does not have quality
					["quantity"] = 1,
					["count"] = 1,
					["quality"] = 1
				}
			}
		},
		["AB"] = { -- Unit in first and in second
			["count"] = 234+456,
			["items"] = {
				["ABA"] = { -- Item in first, not in second
					["quantity"] = 4,
					["count"] = 5,
					["quality"] = 1
				},
				["ABB"] = { -- Item in first and in second
					["quantity"] = 7+10,
					["count"] = 8+11,
					["quality"] = 1
				},
				["ABC"] = { -- Item not in first, is in second
					["quantity"] = 13,
					["count"] = 14,
					["quality"] = 1
				}
			}
		},
		["AC"] = { -- Unit empty in first, not empty in second
			["count"] = 345+567,
			["items"] = {
				["ACA"] = {
					["quantity"] = 16,
					["count"] = 17,
					["quality"] = 1
				}
			}
		},
		["AD"] = { -- Unit not empty in first, is empty in second
			["count"] = 678+789,
			["items"] = {
				["ADA"] = {
					["quantity"] = 19,
					["count"] = 20,
					["quality"] = 1
				}
			}
		},
		["BA"] = { -- Unit not in first, is in second
			["count"] = 890,
			["items"] = {
				["BAA"] = {
					["quantity"] = 22,
					["count"] = 23,
					["quality"] = 1
				}
			}
		}
	}


	local new = DropRate_UpgradeUnitTableFrom1To2(old)

	lu.assertEquals(new, expected)
end

function testDropRate_RegisterItem_ItemIsNil_NewItemReturned()
	local actual = DropRate_RegisterItem(nil, 123, 456)

	lu.assertEquals(actual, {count = 1, quantity = 123, quality = 456})
end

function testDropRate_RegisterItem_ItemIsNotNil_UpdatedItemReturned()
	local item = {count = 123, quantity = 456, quality = 789}
	local actual = DropRate_RegisterItem(item, 111, 222)

	lu.assertEquals(actual, {count = 123+1, quantity = 456+111, quality = 789})
end

function testDropRate_RegisterItems_ItemsIsNil_NewItemsReturned()
	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={2}, thenReturn={2, 'ITEM 2', 222, nil, 555}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, 'ITEM 3', 333, nil, 666}}

	local expected = {
		['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
		['ITEM 2'] = { count = 1, quantity = 222, quality = 555 },
		['ITEM 3'] = { count = 1, quantity = 333, quality = 666 },
	}

	local actual = DropRate_RegisterItems(nil);

	lu.assertEquals(actual, expected)
end

function testDropRate_RegisterItems_ItemsIsNotNil_UpdatedItemsReturned()
	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={2}, thenReturn={2, 'ITEM 2', 222, nil, 555}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, 'ITEM 3', 333, nil, 666}}

	local items = {
		['ITEM 2'] = { count = 123, quantity = 777, quality = 888 },
		['ITEM 4'] = { count = 234, quantity = 999, quality = 000 },
	}

	local expected = {
		['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
		['ITEM 2'] = { count = 123+1, quantity = 777+222, quality = 888 },
		['ITEM 3'] = { count = 1, quantity = 333, quality = 666 },
		['ITEM 4'] = { count = 234, quantity = 999, quality = 000 },
	}

	local actual = DropRate_RegisterItems(items);

	lu.assertEquals(actual, expected)
end

function testDropRate_RegisterItems_LootSlotHasNoItem_ItemSkippedAndUpdatedItemsReturned()
	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={false}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, 'ITEM 3', 333, nil, 666}}

	local items = {
		['ITEM 2'] = { count = 123, quantity = 777, quality = 888 },
		['ITEM 4'] = { count = 234, quantity = 999, quality = 000 },
	}

	local expected = {
		['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
		['ITEM 2'] = { count = 123, quantity = 777, quality = 888 },
		['ITEM 3'] = { count = 1, quantity = 333, quality = 666 },
		['ITEM 4'] = { count = 234, quantity = 999, quality = 000 },
	}

	local actual = DropRate_RegisterItems(items);

	lu.assertEquals(actual, expected)
end

function testDropRate_RegisterItems_LootSlotIsCoins_CoinsSkippedAndUpdatedItemsReturned()
	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={2}, thenReturn={2, 'ITEM 2', 222, nil, 555}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, '3 COINS', 333, nil, 666}}

	local items = {
		['ITEM 2'] = { count = 123, quantity = 777, quality = 888 },
		['ITEM 4'] = { count = 234, quantity = 999, quality = 000 },
	}

	local expected = {
		['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
		['ITEM 2'] = { count = 123+1, quantity = 777+222, quality = 888 },
		['ITEM 4'] = { count = 234, quantity = 999, quality = 000 },
	}

	local actual = DropRate_RegisterItems(items);

	lu.assertEquals(actual, expected)
end

function testDropRate_RegisterUnit_UnitIsNil_NewUnitReturned()
	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={2}, thenReturn={2, 'ITEM 2', 222, nil, 555}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, 'ITEM 3', 333, nil, 666}}

	local expected = {
		count = 1,
		items = {
			['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
			['ITEM 2'] = { count = 1, quantity = 222, quality = 555 },
			['ITEM 3'] = { count = 1, quantity = 333, quality = 666 },
		}
	}

	local actual = DropRate_RegisterUnit(nil)

	lu.assertEquals(actual, expected)
end

function testDropRate_RegisterUnit_UnitIsNotNil_UpdatedUnitReturned()
	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={2}, thenReturn={2, 'ITEM 2', 222, nil, 555}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, 'ITEM 3', 333, nil, 666}}

	local unit = {
		count = 123,
		items = {
			['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
		}
	}

	local expected = {
		count = 123+1,
		items = {
			['ITEM 1'] = { count = 1+1, quantity = 111+111, quality = 444 },
			['ITEM 2'] = { count = 1, quantity = 222, quality = 555 },
			['ITEM 3'] = { count = 1, quantity = 333, quality = 666 },
		}
	}

	local actual = DropRate_RegisterUnit(unit)

	lu.assertEquals(actual, expected)
end

function testDropRate_OnLootOpened_UnitTableIsNil_EarlyOut()
	DropRate_UnitTable = nil;

	DropRate_OnLootOpened()

	lu.assertEquals(DropRate_UnitTable, nil)
end

function testDropRate_OnLootOpened_TargetUnitIsNotDead_EarlyOut()
	DropRate_UnitTable = {};

	UnitIsDead = Mock()
	UnitIsDead:whenCalled{with={'target'}, thenReturn={false}}

	DropRate_OnLootOpened()

	lu.assertEquals(DropRate_UnitTable, {})
end

function testDropRate_OnLootOpened_CannotGetTargetUnitGUID_EarlyOut()
	DropRate_UnitTable = {};

	UnitIsDead = Mock()
	UnitIsDead:whenCalled{with={'target'}, thenReturn={true}}

	UnitGUID = Mock()
	UnitGUID:whenCalled{with={'target'}, thenReturn={nil}}

	DropRate_OnLootOpened()

	lu.assertEquals(DropRate_UnitTable, {})
end

function testDropRate_OnLootOpened_TargetUnitGUIDIsInUniqueTargetTable_EarlyOut()
	DropRate_UnitTable = {};
	DropRate_UniqueUnitTable = {['GUID 1'] = 1234}

	UnitIsDead = Mock()
	UnitIsDead:whenCalled{with={'target'}, thenReturn={true}}

	UnitGUID = Mock()
	UnitGUID:whenCalled{with={'target'}, thenReturn={'GUID 1'}}

	DropRate_OnLootOpened()

	lu.assertEquals(DropRate_UnitTable, {})
end

function testDropRate_OnLootOpened_TargetUnitGUIDIsNotInUniqueTargetTable_UnitRegistered()
	DropRate_UnitTable = {['UNIT 1'] = {['count'] = 123, ['items'] = {}}}
	DropRate_UniqueUnitTable = {['GUID 1'] = 1234}

	UnitIsDead = Mock()
	UnitIsDead:whenCalled{with={'target'}, thenReturn={true}}

	UnitGUID = Mock()
	UnitGUID:whenCalled{with={'target'}, thenReturn={'GUID 2'}}

	UnitName = Mock()
	UnitName:whenCalled{with={'target'}, thenReturn={'UNIT 2'}}

	time = Mock()
	time:whenCalled{thenReturn={2345}}

	GetNumLootItems = Mock()
	GetNumLootItems:whenCalled{thenReturn={3}}

	LootSlotHasItem = Mock()
	LootSlotHasItem:whenCalled{with={1}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={2}, thenReturn={true}}
	LootSlotHasItem:whenCalled{with={3}, thenReturn={true}}

	GetLootSlotInfo = Mock()
	GetLootSlotInfo:whenCalled{with={1}, thenReturn={1, 'ITEM 1', 111, nil, 444}}
	GetLootSlotInfo:whenCalled{with={2}, thenReturn={2, 'ITEM 2', 222, nil, 555}}
	GetLootSlotInfo:whenCalled{with={3}, thenReturn={3, 'ITEM 3', 333, nil, 666}}

	local expected = {
		['UNIT 1'] = {
			['count'] = 123,
			['items'] = {}
		},
		['UNIT 2'] = {
			count = 1,
			items = {
				['ITEM 1'] = { count = 1, quantity = 111, quality = 444 },
				['ITEM 2'] = { count = 1, quantity = 222, quality = 555 },
				['ITEM 3'] = { count = 1, quantity = 333, quality = 666 },
			}
		}
	}

	DropRate_OnLootOpened()

	lu.assertEquals(DropRate_UnitTable, expected)
	lu.assertEquals(DropRate_UniqueUnitTable, {['GUID 1'] = 1234, ['GUID 2'] = 2345})
end

os.exit(lu.LuaUnit.run())
