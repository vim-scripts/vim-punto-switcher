" -------------------------------------------------------------------------------
"  Vim punto switcher
" -------------------------------------------------------------------------------

let g:vim_punto_switcher_loaded = 1
let g:vim_punto_switcher_version = 100

" set up charmaps

let s:dCharMaps = {
         \     'en' : '`1234567890-=qwertyuiop[]\asdfghjkl;'''.'zxcvbnm,./~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?',
         \     'ru' : 'ё1234567890-=йцукенгшщзхъ\фывапролджэ' .'ячсмитьбю.Ё!"№;%:?*()_+ЙЦУКЕНГШЩЗХЪ/ФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,',
         \  }


" need to convert encoding if current &encoding is not utf-8
if &encoding != 'utf-8'

   for s:sKey in keys(s:dCharMaps)
      let s:dCharMaps[ s:sKey ] = iconv(s:dCharMaps[ s:sKey ], 'utf-8', &encoding)
   endfor
   unlet s:sKey

endif



" changes text between two marks
function! <SID>ReplaceTextBetweenMarks(mark1, mark2, sText)

   let reg = 't'

   " save current state of temp register
   let [save_reg, save_type] = [getreg(reg), getregtype(reg)]

   " save current visual selection marks
   "let [save_vs_start, save_vs_end] = [getpos("'<"), getpos("'>")]
   
   " change text between marks
   " always set this register as characterwise! (3rd parameter of setreg())
   " because otherwise there will be bugs.
   call setreg(reg, a:sText, 'v')
   exec 'normal! `'.a:mark1.'v`'.a:mark2.'"tP'

   " restore temp register
   call setreg(reg, save_reg, save_type)

   " restore visual selection marks
   "call setpos("'<", save_vs_start)
   "call setpos("'>", save_vs_end)
endfunction


" switch charmap.
" @param sText:      original text
" @param direction:  "en-ru" means translate from en to ru
"                    "ru-en" means translate from ru to en
function! <SID>SwitchCharmap(sText, direction)

   let l:lMaps = split(a:direction, '-')

   if len(l:lMaps) == 2 && has_key(s:dCharMaps, l:lMaps[0]) && has_key(s:dCharMaps, l:lMaps[1])

      let l:sMap_from = s:dCharMaps[ l:lMaps[0] ]
      let l:sMap_to   = s:dCharMaps[ l:lMaps[1] ]

      return tr(a:sText, l:sMap_from, l:sMap_to)
   else
      return ""
   endif

endfunction

function! <SID>GetGVText()
   let reg = 't'

   " save current state of temp register
   let [save_reg, save_type] = [getreg(reg), getregtype(reg)]

   " get selected text
   exec 'normal! gv"'.reg.'y'
   let l:sText = @t

   " restore temp register
   call setreg(reg, save_reg, save_type)

   return l:sText

endfunction


" swith charmap for currently selected text
" @param direction:  "en-ru" means translate from en to ru
"                    "ru-en" means translate from ru to en
function! <SID>SwitchLangmapForSelectedText(direction)

   let l:sText = <SID>GetGVText()
   let l:sText = <SID>SwitchCharmap(l:sText, a:direction)

   call <SID>ReplaceTextBetweenMarks('<', '>', l:sText)

endfunction

function! <SID>GetTextBetweenTwoPos(lPos1, lPos2)
   
   let vs_start = '<'
   let vs_end   = '>'

   let mark1 = 'q'
   let mark2 = 'w'

   " save current visual selection
   let [save_vs_start, save_vs_end] = [ getpos("'".vs_start), getpos("'".vs_end) ]
   " save current marks
   let [save_mark1, save_mark2]     = [ getpos("'".mark1),    getpos("'".mark2)  ]

   call setpos("'".mark1, [
            \     0,
            \     a:lPos1['lnum'],
            \     a:lPos1['col'],
            \     0,
            \  ])

   call setpos("'".mark2, [
            \     0,
            \     a:lPos2['lnum'],
            \     a:lPos2['col'],
            \     0,
            \  ])

   let reg = 't'

   " save current state of temp register
   let [save_reg, save_type] = [getreg(reg), getregtype(reg)]

   exec 'normal! `'.mark1.'v`'.mark2.'"'.reg.'y'
   let l:sText = @t

   " restore visual selection
   "call setpos("'".mark1, save_vs_start)
   "call setpos("'".mark2, save_vs_end)

   "exec 'normal! `'.mark1.'v`'.mark2.'"'.reg.'y'

   " restore marks
   call setpos("'".mark1, save_mark1)
   call setpos("'".mark2, save_mark2)

   " restore temp register
   call setreg(reg, save_reg, save_type)

   return l:sText

endfunction

" TODO: make configurable
function! <SID>InvertCharMapName(sName)
   if a:sName == g:pswitcher_two_main_maps[0]
      return g:pswitcher_two_main_maps[1]
   elseif a:sName == g:pswitcher_two_main_maps[1]
      return g:pswitcher_two_main_maps[0]
   else
      return a:sName
   endif
endfunction

function! <SID>SwitchLangmapInputAuto(sMode, sVimMode)

   let mark_start = 'q'
   let mark_end   = 'w'

   if a:sVimMode == 'i'
      " break undo sequence.
      " (divide changes in several undo items in undo history)
      " works strange, though.
      call feedkeys("\<C-G>u")
   endif

   " save current marks
   let [save_mark_start, save_mark_end] = [getpos("'".mark_start), getpos("'".mark_end)]

   let curpos = getpos(".")
   let [lnum, col] = curpos[1 : 2]


   " if current cursor pos is different from previous session's cursor pos,
   " then we should calculate start pos, otherwise just take previous start pos.
   if s:dPrevCond['end_lnum'] == lnum && s:dPrevCond['end_virtcol'] == virtcol(".")
      " use previous start pos
      if a:sMode == 'auto'
         let l:dRes = s:dPrevCond['dStartPosAndCurrentMapName']
         let l:dRes['cur_map_name'] = <SID>InvertCharMapName(l:dRes['cur_map_name'])
      elseif a:sMode == 'word'
         let lnum = s:dPrevCond['dStartPosAndCurrentMapName']['start_lnum']
         let col = s:dPrevCond['dStartPosAndCurrentMapName']['start_col'] - 1

         let l:boolOK = 0
         while !l:boolOK
            let l:boolOK = 1

            let l:sTmpStrpart = strpart(getline(lnum), 0, col)

            if (col == 0 || l:sTmpStrpart =~ '\v^\s*$') && lnum > 0
               let lnum = lnum - 1
               let col = strlen(getline(lnum))
               let l:boolOK = 0
            endif

         endwhile

         " calculate new start pos
         let l:dRes = <SID>GetStartPosAndCurrentMapName({
                  \     'lnum' : lnum,
                  \     'col'  : col,
                  \     'mode' : a:sMode,
                  \  })

         let l:dRes['cur_map_name'] = s:dPrevCond['dStartPosAndCurrentMapName']['cur_map_name']
         let s:dPrevCond['dStartPosAndCurrentMapName'] = l:dRes
      endif

   else
      " in 'word' mode we need to use end of current word, not exact cursor pos.
      if a:sMode == 'word'
         let l:sTmpLine = strpart(getline(lnum), col - 1)
         if strlen(l:sTmpLine) > 0
            if l:sTmpLine[0] !~ '\s'
               let l:lTmpList = split(l:sTmpLine)
               if len(l:lTmpList) > 0
                  let col = col + strlen(l:lTmpList[0])
               endif
            endif
         endif

      endif

      " calculate new start pos
      let l:dRes = <SID>GetStartPosAndCurrentMapName({
               \     'lnum' : lnum,
               \     'col'  : col,
               \     'mode' : a:sMode,
               \  })

      let s:dPrevCond = {
               \     'end_lnum' : lnum,
               \     'end_virtcol'  : virtcol("."),
               \     'dStartPosAndCurrentMapName' : l:dRes
               \  }

   endif

   let l:sInvertedCharMapName = <SID>InvertCharMapName(l:dRes['cur_map_name'])

   if !empty(l:sInvertedCharMapName) && l:dRes['start_lnum'] >= 0 && l:dRes['start_col'] >= 0
      let l:sDirection = l:dRes['cur_map_name'].'-'.l:sInvertedCharMapName
      
      " get text between two needed positions

      let l:dStartPos = {
               \     'lnum' : l:dRes['start_lnum'],
               \     'col'  : l:dRes['start_col'],
               \  }
      let l:dEndPos = {
               \     'lnum' : lnum,
               \     'col'  : col,
               \  }

      let l:sText = <SID>GetTextBetweenTwoPos(l:dStartPos, l:dEndPos)

      " set marks to this positions

      call setpos("'".mark_start, [
               \     0,
               \     l:dRes['start_lnum'],
               \     l:dRes['start_col'],
               \     0,
               \  ])

      call setpos("'".mark_end, [
               \     0,
               \     lnum,
               \     col,
               \     0,
               \  ])

      " switch charmap
      let l:sText = <SID>SwitchCharmap(l:sText, l:sDirection)
      " replace text
      call <SID>ReplaceTextBetweenMarks(mark_start, mark_end, l:sText)

   else
      echo "vim-punto-switcher: sorry, i'm not really sure what are you trying to do."
   endif

   " restore marks
   call setpos("'".mark_start, save_mark_start)
   call setpos("'".mark_end,   save_mark_end)

   call setpos(".", curpos)
   "echo l:dRes

endfunction


function! <SID>GetStartPosAndCurrentMapName(dEndPos)
   let lnum    = a:dEndPos['lnum']
   let col     = a:dEndPos['col']
   let mode    = a:dEndPos['mode']

   let l:dRes = {
            \     'start_lnum'   : lnum,
            \     'start_col'    : 0,
            \     'cur_map_name' : '',
            \  }


   let l:sSourceCharMapName = ''
   let l:boolStartFound = 0

   let l:iLinesParsedCnt = 0

   while l:iLinesParsedCnt < g:pswitcher_max_lines_auto && !l:boolStartFound

      let line = getline(lnum)

      " if this isn't the first line we parse, then put col at the last
      " position of line
      if l:iLinesParsedCnt > 0
         " no " - 1" is needed here!
         let col = strlen(line)
      endif


      while col > 0
         let col = col - 1
         let l:sCurChar = line[col]

         let l:lAllMapNames = keys(s:dCharMaps)

         if empty(l:sSourceCharMapName)
            " we don't know direction. let's see if current character is present
            " in several keymaps or only in one

            let l:iCnt = 0
            for l:sCurMapName in l:lAllMapNames

               if stridx(s:dCharMaps[ l:sCurMapName ], l:sCurChar) != -1
                  let l:iCnt = l:iCnt + 1
                  if l:iCnt > 1
                     " if number is 2 or more then break, because continue here
                     " makes no sense
                     let l:sSourceCharMapName = ''
                     break
                  endif
                  let l:sSourceCharMapName = l:sCurMapName
               endif

            endfor

            if !empty(l:sSourceCharMapName)
               " source charmap found!
               let l:dRes['cur_map_name'] = l:sSourceCharMapName
               let l:dRes['start_lnum'] = lnum
               let l:dRes['start_col'] = col
            endif

         else
            " source charmap is already known.
            " check: if current char is NOT present in source charmap, but present in
            " some another charmap, then we found start position.

            let l:boolNotExistsInSrc = 1
            let l:boolExistsInAnother = 0
            for l:sCurMapName in l:lAllMapNames

               if stridx(s:dCharMaps[ l:sCurMapName ], l:sCurChar) != -1
                  if l:sCurMapName == l:sSourceCharMapName
                     let l:boolNotExistsInSrc = 0
                  else
                     let l:boolExistsInAnother = 1
                  endif
               endif

            endfor


            " in 'word' mode we should take in account all non-whitespace char, 
            " but in 'auto' mode take only chars that exists in source charmap,
            " and does not exist in any other charmap.
            if mode == 'word'
               if l:sCurChar !~ '\s'
                  let l:dRes['start_lnum'] = lnum
                  let l:dRes['start_col'] = col
               endif
            elseif mode == 'auto'
               if !l:boolNotExistsInSrc && !l:boolExistsInAnother
                  " current char exists in src charmap, and ONLY in src charmap. let's
                  " remember its number
                  let l:dRes['start_lnum'] = lnum
                  let l:dRes['start_col'] = col
               endif
            endif

            if l:boolNotExistsInSrc && l:boolExistsInAnother
               " start found!
               let l:boolStartFound = 1
               break
            endif

            " in 'word' mode we should also break at first space char
            if mode == 'word'
               if l:sCurChar =~ '\s'
                  " start found!
                  let l:boolStartFound = 1
                  break
               endif
            endif


         endif


      endwhile

      if mode == 'word' && !empty(l:sSourceCharMapName)
         let l:boolStartFound = 1
      endif

      if !l:boolStartFound
         let lnum = lnum - 1
         let l:iLinesParsedCnt = l:iLinesParsedCnt + 1
      endif

   endwhile

   let l:dRes['start_col'] = (l:dRes['start_col'] + 1)

   if !l:boolStartFound && (l:dRes['start_lnum'] > 1 || l:dRes['start_col'] > 1)
      let l:dRes['start_lnum'] = -1
      let l:dRes['start_col']  = -1
   endif

   return l:dRes

endfunction


let s:dPrevCond = {
         \     'end_lnum' : -1,
         \     'end_col'  : -1,
         \     'end_virtcol'  : -1,
         \     'dStartPosAndCurrentMapName' : {}
         \  }

" set up mappings

vnoremap <silent> <script> <Plug>(pswitcher-selected-en-ru)
         \        :<C-u>call <SID>SwitchLangmapForSelectedText("en-ru")<CR>

vnoremap <silent> <script> <Plug>(pswitcher-selected-ru-en)
         \        :<C-u>call <SID>SwitchLangmapForSelectedText("ru-en")<CR>

inoremap <silent> <script> <Plug>(pswitcher-input-auto)
         \        <C-O>:call <SID>SwitchLangmapInputAuto('auto', 'i')<CR>

noremap  <silent> <script> <Plug>(pswitcher-auto)
         \        :call <SID>SwitchLangmapInputAuto('auto', 'n')<CR>

inoremap <silent> <script> <Plug>(pswitcher-input-word)
         \        <C-O>:call <SID>SwitchLangmapInputAuto('word', 'i')<CR>

noremap  <silent> <script> <Plug>(pswitcher-word)
         \        :call <SID>SwitchLangmapInputAuto('word', 'n')<CR>



if !exists('g:pswitcher_no_default_key_mappings')
   let g:pswitcher_no_default_key_mappings = 0
endif

if !exists('g:pswitcher_max_lines_auto')
   let g:pswitcher_max_lines_auto = 10
endif

if !exists('g:pswitcher_two_main_maps')
   let g:pswitcher_two_main_maps = [ 'en', 'ru' ]
endif


if !g:pswitcher_no_default_key_mappings
   silent! vmap <unique> ,er <Plug>(pswitcher-selected-en-ru)
   silent! vmap <unique> ,re <Plug>(pswitcher-selected-ru-en)

   silent! imap <unique> <F4> <Plug>(pswitcher-input-word)
   silent! map  <unique> <F4> <Plug>(pswitcher-word)

   silent! imap <unique> <S-F4> <Plug>(pswitcher-input-auto)
   silent! map  <unique> <S-F4> <Plug>(pswitcher-auto)
endif

