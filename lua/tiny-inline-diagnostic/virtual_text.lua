local M = {}

local chunk_utils = require("tiny-inline-diagnostic.chunk")
local highlights = require("tiny-inline-diagnostic.highlights")
local plugin_handler = require("tiny-inline-diagnostic.plugin")
local utils = require("tiny-inline-diagnostic.utils")

--- @param opts table containing options
--- @param cursorpos table containing cursor position
--- @param index_diag integer representing the diagnostic index
function M.from_diagnostic(opts, ret, cursorpos, index_diag, padding, total_chunks)
	local diag_hi, diag_inv_hi = highlights.get_diagnostic_highlights(ret.severity)

	local all_virtual_texts = {}

	local chunks = ret.chunks
	local need_to_be_under = ret.need_to_be_under
	local offset = ret.offset
	local offset_win_col = ret.offset_win_col
	local source = ret.source

	if opts.options.show_source and source ~= nil then
		chunks[#chunks] = chunks[#chunks] .. " (" .. source .. ")"
	end

	for index_chunk = 1, #chunks do
		local message = utils.trim(chunks[index_chunk])

		local to_add = padding - #message
		message = message .. string.rep(" ", to_add)

		if index_chunk == 1 then
			local chunk_header = chunk_utils.get_header_from_chunk(
				message,
				index_diag,
				#chunks,
				need_to_be_under,
				opts,
				diag_hi,
				diag_inv_hi,
				total_chunks
			)

			if index_diag == 1 then
				local chunk_arrow = chunk_utils.get_arrow_from_chunk(opts, need_to_be_under)

				if type(chunk_arrow[1]) == "table" then
					table.insert(all_virtual_texts, chunk_arrow)
				else
					table.insert(chunk_header, 1, chunk_arrow)
				end
			end

			table.insert(all_virtual_texts, chunk_header)
		else
			local chunk_body = chunk_utils.get_body_from_chunk(
				message,
				index_diag,
				index_chunk,
				#chunks,
				need_to_be_under,
				opts,
				diag_hi,
				diag_inv_hi,
				total_chunks
			)

			table.insert(all_virtual_texts, chunk_body)
		end
	end

	if need_to_be_under then
		table.insert(all_virtual_texts, 1, {
			{ " ", "None" },
		})
	end

	return all_virtual_texts, offset_win_col, need_to_be_under
end

function M.from_diagnostics(opts, diags, cursor_pos, buf)
	local all_virtual_texts = {}
	local offset_win_col = 0
	local need_to_be_under = false

	local plugin_offset = plugin_handler.handle_plugins(opts)

	local max_chunk_line_length = 0
	local chunks_by_diag = {}

	for index_diag, diag in ipairs(diags) do
		local ret = chunk_utils.get_chunks(opts, diag, plugin_offset, cursor_pos[1], buf)
		local chunk_line_length = chunk_utils.get_max_width_from_chunks(ret.chunks)

		if chunk_line_length > max_chunk_line_length then
			max_chunk_line_length = chunk_line_length
		end

		chunks_by_diag[index_diag] = ret
	end

	for index_diag, ret in ipairs(chunks_by_diag) do
		local virt_texts, diag_offset_win_col, diag_need_to_be_under =
			M.from_diagnostic(opts, ret, cursor_pos, index_diag, max_chunk_line_length, #chunks_by_diag)

		if diag_need_to_be_under == true then
			need_to_be_under = true
		end

		-- Remove new line if not needed
		if need_to_be_under and index_diag > 1 then
			table.remove(virt_texts, 1)
		end

		vim.list_extend(all_virtual_texts, virt_texts)
	end
	return all_virtual_texts, offset_win_col, need_to_be_under
end

return M
