--[[
AdiBags - Adirelle's bag addon.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

function addon:SetupDefaultFilters()

	-- Define global ordering
	self:SetCategoryOrders{
		[L['Quest']] = 30,
		[L['Trade Goods']] = 20,
		[L['Equipment']] = 10,
		[L['Consumable']] = -10,
		[L['Miscellaneous']] = -20,
		[L['Ammunition']] = -30,
		[L['Junk']] = -40,
	}

	-- [90] Parts of an equipment set
	do
		local setFilter = addon:RegisterFilter("ItemSets", 90, "AceEvent-3.0")
		setFilter.uiName = L['Gear manager item sets']
		setFilter.uiDesc = L['Put items belonging to one or more sets of the built-in gear manager in specific sections.']

		function setFilter:OnInitialize()
			self.db = addon.db:RegisterNamespace('ItemSets', {
				profile = { oneSectionPerSet = true },
				char = { mergedSets = { ['*'] = false } },
			})
		end

		function setFilter:OnEnable()
			self:RegisterEvent('EQUIPMENT_SETS_CHANGED')
			self:UpdateSets()
			addon:UpdateFilters()
		end

		local sets = {}
		local setNames = {}

		function setFilter:UpdateSets()
			wipe(sets)
			wipe(setNames)
			for i = 1, GetNumEquipmentSets() do
				local name = GetEquipmentSetInfo(i)
				setNames[name] = name
				local items = GetEquipmentSetItemIDs(name)
				for loc, id in pairs(items) do
					if id and not sets[id] then
						sets[id] = name
					end
				end
			end
		end

		function setFilter:EQUIPMENT_SETS_CHANGED()
			self:UpdateSets()
			self:SendMessage('AdiBags_FiltersChanged')
		end

		function setFilter:Filter(slotData)
			local name = sets[slotData.itemId]
			if name then
				if not self.db.profile.oneSectionPerSet or self.db.char.mergedSets[name] then
					return L['Sets'], L["Equipment"]
				else
					return L["Set: %s"]:format(name), L["Equipment"]
				end
			end
		end
		
		function setFilter:GetFilterOptions()
			return {
				oneSectionPerSet = {
					name = L['One section per set'],
					desc = L['Check this to display one individual section per set. If this is disabled, there will be one big "Sets" section.'],
					type = 'toggle',
					order = 10,
				},
				mergedSets = {
					name = L['Merged sets'],
					desc = L['Check sets that should be merged into a unique "Sets" section. This is obviously a per-character setting.'],
					type = 'multiselect',
					order = 20,
					values = setNames,
					get = function(info, name)
						return self.db.char.mergedSets[name]
					end,
					set = function(info, name, value)
						self.db.char.mergedSets[name] = value
						self:SendMessage('AdiBags_FiltersChanged')
					end,
					disabled = function() return not self.db.profile.oneSectionPerSet end,
				},
			}, addon:GetOptionHandler(self, true)
		end

	end

	-- [80] Ammo and shards
	local ammoFilter = addon:RegisterFilter('AmmoShards', 80, function(filter, slotData)
		if slotData.itemId == 6265 then -- Soul Shard
			return L['Soul shards'], L['Ammunition']
		elseif slotData.equipSlot == 'INVTYPE_AMMO' then
			return L['Ammunition']
		end
	end)
	ammoFilter.uiName = L['Ammunition and soul shards']
	ammoFilter.uiDesc = L['Put ammunition and soul shards in their own sections.']

	-- [70] Low quality items
	do
		local lowQualityPattern = string.format('%s|Hitem:%%d+:0:0:0:0', ITEM_QUALITY_COLORS[ITEM_QUALITY_POOR].hex)
		--@noloc[[
		local junkFilter = addon:RegisterFilter('Junk', 70, function(self, slotData)
			if slotData.class == L['Junk'] or slotData.subclass == L['Junk'] or slotData.link:match(lowQualityPattern) then
				return L['Junk']
			end
		end)
		junkFilter.uiName = L['Junk']
		--@noloc]]
		junkFilter.uiDesc = L['Put items of poor quality or labeled as junk in the "Junk" section.']
	end

	-- [75] Quest Items
	do
		--@noloc[[
		local questItemFilter = addon:RegisterFilter('Quest', 75, function(self, slotData)
			if slotData.class == L['Quest'] or slotData.subclass == L['Quest'] then 
				return L['Quest']
			else
				local isQuestItem, questId = GetContainerItemQuestInfo(slotData.bag, slotData.slot)
				return (questId or isQuestItem) and L['Quest']
			end
		end)
		--@noloc]]
		questItemFilter.uiName = L['Quest Items']
		questItemFilter.uiDesc = L['Put quest-related items in their own section.']
	end

	-- [60] Equipment
	do
		local equipmentFilter = addon:RegisterFilter('Equipment', 60, function(self, slotData)
			local equipSlot = slotData.equipSlot
			if equipSlot and equipSlot ~= "" then
				self:Debug('splitBySlot', slotData.link, equipSlot, _G[equipSlot])
				if self.db.profile.splitBySlot then
					return _G[equipSlot], L['Equipment']
				else
					return L['Equipment']
				end
			end
		end)
		equipmentFilter.uiName = L['Equipment']
		equipmentFilter.uiDesc = L['Put any item that can be equipped (including bags) into the "Equipment" section.']
		
		function equipmentFilter:OnInitialize()
			self.db = addon.db:RegisterNamespace('Equipment', { profile = { splitBySlot = false } })
		end
		
		function equipmentFilter:GetFilterOptions()
			return {
				splitBySlot = {
					name = L['Split by inventory slot'],
					desc = L['Check this to display one section per inventory slot.'],
					type = 'toggle',
					order = 10,
				}
			}, addon:GetOptionHandler(self, true)
		end
	end
	
	-- [10] Item classes
	do
		local itemCat = addon:RegisterFilter('ItemCategory', 10)
		itemCat.uiName = L['Item category']
		itemCat.uiDesc = L['Put items in sections depending on their first-level category at the Auction House.']
			..'\n|cffff7700'..L['Please note this filter matchs every item. Any filter with lower priority than this one will have no effect.']..'|r'

		function itemCat:OnInitialize(slotData)
			self.db = addon.db:RegisterNamespace(self.moduleName, {
				profile = {
					split = false,
					mergeGems = true,
					mergeGlyphs = true,
				}
			})
		end
		
		function itemCat:GetFilterOptions()
			return {
				split = {
					name = L['Split by second-level category'],
					type = 'toggle',
					order = 10,
				},
				mergeGems = {
					name = L['List gems as trade goods'],
					type = 'toggle',
					width = 'double',
					order = 20,
					disabled = function(info) return info.handler:IsDisabled(info) or self.db.profile.split end,
				},
				mergeGlyphs = {
					name = L['List glyphs as trade goods'],
					type = 'toggle',
					width = 'double',
					order = 30,
					disabled = function(info) return info.handler:IsDisabled(info) or self.db.profile.split end,
				},
			}, addon:GetOptionHandler(self, true)
		end
		
		--@noloc[[
		function itemCat:Filter(slotData)
			local class, subclass = slotData.class, slotData.subclass
			local isGem = (class == L["Gem"])
			local isGlyph = (class == L["Glyph"])
			if self.db.profile.split then
				if isGem or isGlyph then
					return class, L["Trade Goods"]
				else
					return subclass, class
				end
			elseif isGem then
				return self.db.profile.mergeGems and L["Trade Goods"] or class, L["Trade Goods"]
			elseif isGlyph then
				return self.db.profile.mergeGlyphs and L["Trade Goods"] or class, L["Trade Goods"]
			else
				return class
			end
		end
		--@noloc]]
		
	end

end
