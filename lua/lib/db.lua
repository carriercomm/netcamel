#!/usr/bin/luajit
--------------------------------------------------------------------------------
--  This file is part of NetCamel
--  Copyright (C) 2014,15 Lee Essen <lee.essen@nowonline.co.uk>
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
------------------------------------------------------------------------------

--
-- TRANSIENT STORAGE using Sqlite3, this will be created at boot time
-- but then used by various systems to facilitate concurrent updates
-- and communication.
--

TABLE = {}

local sqlite3 = require("lsqlite3")
local db = sqlite3.open("lee.sqlite3")

--
-- Insert items into a table based on the fields provided in a hash
--
local function insert_into_table(name, item)
	local vals = ""
	local args = ""
	local rc, stmt
	for k,_ in pairs(item) do
		vals = vals .. ((vals == "" and "") or ", ") .. k
		args = args .. ((args == "" and "") or ", ") .. ":" .. k
	end

	stmt = db:prepare("insert into "..name.." ("..vals..") VALUES ("..args..")")
	if not stmt then return false, "insert prepare failed: "..db:errmsg() end
	rc = stmt:bind_names(item)
	if rc ~= sqlite3.OK then return false, "insert bind failed: "..db:errmsg() end
	rc = stmt:step()
	if rc ~= sqlite3.DONE then return false, "insert step failed: "..db:errmsg() end
	stmt:finalize()
	return true
end

local function custom_query(sql)
	local rc = {}
	for row in db:nrows(sql) do
		table.insert(rc, row)
	end
	return rc
end

--
-- Return a list of all the results of a query that is pre-populated in the
-- TABLE list
--
local function query(name, qname, ...)
	local sql = TABLE[name] and TABLE[name][qname]
	if not sql then return false, "unknown table or query" end

	local stmt = db:prepare(sql)
	if not stmt then return false, "query failed: "..db:errmsg() end

	if select('#', ...) > 0 then
		print("would bind")
		if type(select(1, ...)) == "table" then
			print("table")
			if stmt:bind_names(select(1, ...)) ~= sqlite3.OK then return false, "bind failed: "..db:errmsg() end
		else
			print("non table")
			if stmt:bind_values(...) ~= sqlite3.OK then return false, "bind failed: "..db:errmsg() end
		end
	end

	local rc = {}
	for row in stmt:nrows(sql) do
		table.insert(rc, row)
	end
	stmt:finalize()
	return rc
end

--
-- Create a table given the spec from the TABLE table.
--
local function create_table(name)
	local sql, rc
	local tabdef = TABLE[name] and TABLE[name].schema
	if not tabdef then return false, "unknown table" end

	local fields = {}
	for k,v in pairs(tabdef) do
		table.insert(fields, k.." "..v)
	end
	rc = db:exec("drop table if exists "..name)
	if rc ~= 0 then return false, "unable to drop table" end
	rc = db:exec("create table " .. name .. " (" .. table.concat(fields, ", ") .. ")")
	if rc ~= 0 then return false, "unable to create table" end
	return true
end

return {
	create = create_table,
	query = query,
	insert = insert_into_table
}
