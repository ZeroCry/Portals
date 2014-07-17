servers = {}
LocalPlayer().Transporting = false

-- for the server browser
serversmaster = {
	{ "Server Name", "ip:port", "password", Vector( x, y, z ), Color( r, g, b, a ) }
}

-- this one is for the portal positions etc
-- name, ip:port, password, position, color
servers[ "gm_construct" ] = {
	{ "Server Name", "ip:port", "password", Vector( x, y, z ), Color( r, g, b, a ) }
}

-- Thanks ronny for these spicy regexes and stuff
local match_name = "Name:.-<b>(.-)</b>"
local match_status = "<span class=\"item_color_title\">Status:</span>%s*<span class=\".-\">%s*(.-)%s*</span>"
local match_players = "<span id=\"HTML_num_players\">(.-)</span>.-<span id=\"HTML_max_players\">(.-)</span>"

local function parse_html_text( text )
	if not text then 
		return nil 
	end
	text = text:gsub( "&#(%d+);", function( num ) 
		return string.char( tonumber( num ) ) 
	end )
	text = text:gsub( "&lt;", "<" )
	text = text:gsub( "&gt;", ">" )
	return text
end

function QueryServer( ip, port, table_ )
	local url = Format( "http://www.gametracker.com/server_info/%s:%s", ip, port )
	local name
	local name2
	local name_adjusted
	local alive
	local players
	local players_max
	local to_r
	http.Fetch( url, 
		function( body, length, headers, code )
			local name = body:match( match_name )
			local status = body:match( match_status )
			local players, players_max = body:match( match_players )
			if name then
				name2 = parse_html_text( name )
				name_adjusted = nil
				alive = status == "Alive"
				players = tonumber( players or "" ) or -1
				players_max = tonumber( players_max or "" ) or -1
			end
			to_r = {
				[ "name" ] = name,
				[ "name2" ] = name2,
				[ "alive" ] = alive,
				[ "players" ] = players,
				[ "maxplayers" ] = players_max
			}
			table_.playerstring = to_r[ "players" ] .. "/" .. to_r[ "maxplayers" ]
		end,
		function( error )
		end
	)
end

local ang1 = Angle( 0, 0, 0 )
local offset = Vector( 0, 0, 50 )
local offset1 = Vector( 0, 0, 5 )
local offset2 = Vector( 0, 0, 90 )
o1add = false
o2add = true

local function oscillate( vec, q )
	local num = vec.z
	if q == 1 then
		if o1add then
			num = num + .1
			if num > 90 then
				o1add = false
			end
		else
			num = num - .1
			if num < 5 then
				o1add = true
			end
		end
	elseif q == 2 then
		if o2add then
			num = num + .1
			if num > 90 then
				o2add = false
			end
		else
			num = num - .1
			if num < 5 then
				o2add = true
			end
		end
	end
	return Vector( vec.x, vec.y, num )
end


fns = {}
function util.PreventFlood( name, delay, func )
	assert( type( name ) == "string", "Bad argument #1 to util.PreventFlood: value must be a string, current type is a " .. type( name ) )
	assert( type( delay ) == "number", "Bad argument #2 to util.PreventFlood: value must be a number, current type is a " .. type( delay ) )
	assert( type( func ) == "function", "Bad argument #3 to util.PreventFlood: value must be a function, current type is a " .. type( func ) )
	if not fns[ name ] then
		fns[ name ] = { 
			delay = delay, 
			time = -1, 
			func = func 
		}
	end
	if fns[ name ] then
		if fns[ name ].time == -1 then
			fns[ name ].time = CurTime()
			fns[ name ].func()
		else
			if CurTime() - fns[ name ].time < fns[ name ].delay then	
				return
			elseif CurTime() - fns[ name ].time >= fns[ name ].delay then
				fns[ name ].time = -1
			end
		end
	end
end

surface.CreateFont( "PortalFont", {
	font = "Arial",
	size = 100,
	antialias = true
} )

surface.CreateFont( "ConnectingFont", {
	font = "Arial",
	size = 60,
	antialias = true
} )

function SetTransporting( value )
	if type( value ) == "table" then
		LocalPlayer().Transporting = true
		local reps = 5
		timer.Create( "Transporting", 1, 5, function()
			reps = reps - 1
			if reps == 0 then
				hook.Remove( "HUDPaint", "DrawConnectOverlay" )
				timer.Destroy( "Transporting" )
				LocalPlayer():SetDSP( 1 )
				LocalPlayer().Transporting = false
				LocalPlayer():ConCommand( "connect " .. value[ 2 ] .. ";password " .. value[ 3 ] )
			end
		end )
		LocalPlayer():SetDSP( 30 )
		local alpha = 0
		hook.Add( "HUDPaint", "DrawConnectOverlay", function()
			surface.SetDrawColor( 0, 0, 0, alpha )
			surface.DrawRect( 0, 0, ScrW(), ScrH() )
			surface.SetTextColor( color_white )
			surface.SetFont( "ConnectingFont" )
			local name = "Connecting to " .. value[ 1 ]
			local name2 = reps
			local name_s = surface.GetTextSize( name )
			local name2_s = surface.GetTextSize( name2 )
			surface.SetTextPos( ( ScrW() / 2 ) - ( name_s / 2 ), ScrH() / 2 )
			surface.DrawText( name )
			surface.SetTextPos( ( ScrW() / 2 ) - ( name2_s / 2 ), ScrH() / 2 + 50 )
			surface.DrawText( name2 )
			alpha = alpha + 0.6
			if alpha > 255 then
				alpha = 255
			end
		end )
	elseif type( value ) == "boolean" then
		if value == false then
			hook.Remove( "HUDPaint", "DrawConnectOverlay" )
			timer.Destroy( "Transporting" )
			LocalPlayer():SetDSP( 1 )
			LocalPlayer().Transporting = false
		end
	end
end

timer.Create( "RefreshPlayerCounts", 5, 0, function()
	if servers[ game.GetMap() ] then
		for k, v in next, servers[ game.GetMap() ] do
			local ip_port = v[ 2 ]
			local ip = string.sub( ip_port, 1, string.find( ip_port, ":" ) - 1 )
			local port = string.sub( ip_port, string.find( ip_port, ":" ) + 1 )
			QueryServer( ip, port, v )
		end
	end
end )

hook.Add( "PostDrawOpaqueRenderables", "DrawFlags", function()
	if servers[ game.GetMap() ] == nil then
		return
	end
	for k, v in next, servers[ game.GetMap() ] do
		local col = v[ 5 ]
		local trace = v[ 4 ]
		cam.Start3D2D( trace + offset1, ang1, 0.5 )
			surface.DrawCircle( 0, 0, 100, col ) 
		cam.End3D2D()
		cam.Start3D2D( trace + offset2, ang1, 0.5 )
			surface.DrawCircle( 0, 0, 100, col ) 
		cam.End3D2D()	
		ang1 = ang1 + Angle( 0, 0.02, 0 )
		local ang = LocalPlayer():EyeAngles()
		local pos = trace + offset + ang:Up()		
		ang:RotateAroundAxis( ang:Forward(), 90 )
		ang:RotateAroundAxis( ang:Right(), 90 )
		surface.SetDrawColor( col )
		cam.Start3D2D( pos, Angle( 0, ang.y, 90 ), 0.1 )
			if v.playerstring then
				draw.SimpleText( v[ 1 ] .. " (" .. v.playerstring .. ")", "PortalFont", x, y, Color( 255, 255, 255 ), TEXT_ALIGN_CENTER )
			else
				draw.SimpleText( v[ 1 ] .. " (" .. "Loading" .. ")", "PortalFont", x, y, Color( 255, 255, 255 ), TEXT_ALIGN_CENTER )
			end
		cam.End3D2D()
		offset1 = oscillate( offset1, 1 )
		offset2 = oscillate( offset2, 2 )
	end
end )

hook.Add( "Think", "TransportPlayers", function()
	if servers[ game.GetMap() ] == nil then
		return
	end
	if not IsValid( LocalPlayer() ) then
		return
	end
	util.PreventFlood( "transport", 0.2, function()
		local _in = {}
		for k, v in next, servers[ game.GetMap() ] do
			if LocalPlayer():GetPos():Distance( v[ 4 ] ) < 90 then
				table.insert( _in, v )
			end
		end
		if table.Count( _in ) == 0 then
			if LocalPlayer().Transporting == true then
				SetTransporting( false )
			end	
		elseif table.Count( _in ) == 1 then
			if not LocalPlayer().Transporting then
				SetTransporting( _in[ 1 ] )
			end
		elseif table.Count( _in ) > 1 then
			if LocalPlayer().Transporting == true then
				SetTransporting( false )
			end
		end
	end )
end )

-- Customization
	local bgcolor = Color( 0, 0, 0, 240 )
	local outlinecolor = Color( 255, 255, 255, 255 )
	local pnl_w = 500
	local pnl_h = 300
	local pnl_font = "Calibri"
	local pnl_font_size = 17
	local pnl_title = "Server List"
--

local main
local plist
local plistview

local function DrawSize( pnl )
	return 0, 0, pnl:GetSize()
end
local function AddSpacer( h )
	local pnl = vgui.Create( "DPanel" )
	pnl:SetSize( 0, h )
	pnl.Paint = function()
	end
	list:AddItem( pnl ) 
end

surface.CreateFont( "ListFont", { 
	font = pnl_font,
	size = pnl_font_size,
	antialias = true
} )

function OpenServerList()

	if main then
		return
	end
	
	main = vgui.Create( "DFrame", vgui.GetWorldPanel() )
	main:SetSize( pnl_w, pnl_h )
	main:SetVisible( true )
	main:Center()
	main:MakePopup()
	main:SetTitle( pnl_title )
	--main.btnMinim:Hide()
	--main.btnMaxim:Hide()
	main.Paint = function()
		surface.SetDrawColor( bgcolor )
		surface.DrawRect( DrawSize( main ) )
		surface.SetDrawColor( outlinecolor )
		surface.DrawOutlinedRect( DrawSize( main ) )
	end
	main.OnClose = function()
		main:Remove()
		if main then
			main = nil
		end
	end
	
	local list = vgui.Create( "DPanelList", main )
	list:Dock( FILL )
	list:EnableVerticalScrollbar( true )
	list:SetSpacing( 5 )
	
	for k, v in next, serversmaster do
		local pnl = vgui.Create( "DPanel" )
		pnl:SetSize( list:GetWide() - 4, 50 )
		pnl:SetPos( 2, 2 )
		pnl.Paint = function()
			surface.SetDrawColor( outlinecolor )
			surface.DrawOutlinedRect( DrawSize( pnl ) )
			surface.SetTextColor( outlinecolor )
			surface.SetFont( "ListFont" )
			surface.SetTextPos( 8, 30 )
			surface.DrawText( v[ 1 ] )
		end
		
		local html = pnl:Add( "HTML" )
		html:SetHTML([[<a href="http://www.gametracker.com/server_info/]] .. v[ 2 ] .. [[/" target="_blank"><img src="http://cache.www.gametracker.com/server_info/]] .. v[ 2 ] .. [[/b_350_20_692108_381007_FFFFFF_000000.png" border="0" width="350" height="20" alt=""/></a>]])
		html:Dock( FILL )
		
		local connect = pnl:Add( "DButton" )
		connect:SetPos( 370, 10 )
		connect:SetSize( 100, 30 )
		connect:SetText( "Connect" )
		connect:SetTextColor( outlinecolor )
		connect.Paint = function()
			surface.SetDrawColor( outlinecolor )
			surface.DrawOutlinedRect( DrawSize( connect ) )
		end
		connect.OnCursorEntered = function()
			connect:SetTextColor( Color( 0, 255, 0 ) )
		end
		connect.OnCursorExited = function()
			connect:SetTextColor( outlinecolor )
		end
		connect.DoClick = function()
			LocalPlayer():ConCommand( "connect " .. v[ 2 ] .. ";password " .. v[ 3 ] )
		end

		list:AddItem( pnl )
	end
	
end

hook.Add( "OnPlayerChat", "ChatCommand", function( ply, text )
	if ply == LocalPlayer() then
		if text == "!servermenu" or text == "!servers" then
			OpenServerList()
		end
	end
end )