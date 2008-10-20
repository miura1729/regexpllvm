#!/bin/env ruby
# -*- coding: utf-8 -*-
# Reguler Expression Compiler
class RegexpMatcher
  class StateMan
    def initialize
      @nstate = 0
      @state = []
      @state[0] = {}
      @loopstack = []
      @newloopchar = []
      @popf = false
    end
    
    attr :state
    
    def add_edge(ch, fm, to, loopchar)
      if loopchar != [] and 
          (@loopstack.last == nil or  
             @loopstack.last[1] != loopchar) then
        
        @loopstack.push [to, loopchar]
        loopchar.each do |ch|
          @state[fm][ch] = to
        end
      end
      
      if @loopstack.last then
        if @loopstack.last[1].include?(ch) then
          @newloopchar.push ch
          #        @popf = false
        end
      end
      if loopchar != [] then
        @popf = false
      end
      
      @state[fm][ch] = to
    end
    
    def init_state
=begin # For debug
         @loopstack.each do |n| 
          print "(#{n[0]}, #{n[1].size}) " end
         print "\n"
         p @newloopchar.size
=end
      @loopstack.pop if @popf
      @popf = true
      if @newloopchar != [] then
        @loopstack.push [@nstate, @newloopchar]
      end
      @newloopchar = []
      @loopstack.each do |lc|
        lc[1].each do |c|
          @state[@nstate][c] = lc[0]
        end
      end
    end
    
    def new_state
      @nstate += 1
      @state[@nstate] = {}
      @nstate
    end
    
    def get_next_state(cstate, ch)
      ret = @state[cstate][ch]
      if ret == @nstate then
        ret = true
      end
      
      ret
    end
    
    def inspect
      res = ""
      @state.each_with_index do |ele, i|
        res += "\nState #{i}\n"
        defval = ele[256]
        ele.each do |key, val|
          if val != defval then
            res += "'#{key.chr}' => #{val}\n"
          end
        end
        res += "... => #{defval}\n"
      end
      
      res
    end
  end
  
  public
  
  def make_stm(restr)
    stm = StateMan.new
    inx = 1
    cst = 0
    while inx <= restr.size do
      inx, cst = make_stm_one(restr, inx, cst, stm)
    end
    stm
  end
  
  def match(stm, str)
    state = 0
    str.each_byte do |ch|
      state = stm.get_next_state(state, ch)
      if state == nil then
        return false
      end
      
      if state == true then
        return true
      end
    end
    false
  end
  
  private
  
  def chr_range(ch)
    case ch
    when '.'
      (0..256).map {|n| n}
    else
      [ch.ord]
    end
  end
  
  def make_stm_one(restr, inx, cst, stm, nst = nil)
    if restr[inx - 1] == '\\' then
      stm.init_state
      nst = nst ? nst : stm.new_state
      stm.add_edge(restr[inx].ord, cst, nst, [])
      return [inx + 1, nst]
    end
    
    case restr[inx]
      
    when '*'
      stm.init_state
      nst = stm.new_state
      loopc = chr_range(restr[inx - 1])
      loopc.each do |ch|
        stm.add_edge(ch, cst, nst, loopc)
      end
      foo, nnst = make_stm_one(restr, inx + 2, cst, stm)
      
      loopc.each do |ch|
        stm.add_edge(ch, nst, nst, [])
      end
      make_stm_one(restr, inx + 2, nst, stm, nnst)
      
      return [inx + 3, nnst]
      
    else
      stm.init_state
      nst = nst ? nst : stm.new_state
      chr_range(restr[inx - 1]).each do |ch|
        stm.add_edge(ch, cst, nst, [])
      end
      return [inx + 1, nst]
    end
  end
end  
  
  
class RegexpMatcherRuby66<RegexpMatcher
  def compile(restr)
    stm = make_stm(restr)
    res = "i = -1\n"
    starray = stm.state
    starray.each_with_index do |elest, stn|
      res += "#{stn}:\n"
      
      if stn == starray.size - 1 then
        res += "return true"
      else
        res += "i = i + 1\n"
        res += "if i > maxlen then return false\n"
        defstat = elest[256]
        elest.each do |key, val|
          if val != defstat then
            res += "if ch[i] == '#{key.chr}' then goto #{val}\n"
          end
        end
        if defstat then
          res += "goto #{defstat}\n"
        else
          res += "return false\n"
        end
      end
    end
    
    res
  end
end

require 'tempfile'
require 'rubygems'
require 'llvm'

class RegexpMatcherLLVM<RegexpMatcher  
  include LLVM
  include RubyInternals
  def initialize
    @module = LLVM::Module.new('regexp')
    ExecutionEngine.get(@module)
    @func = @module.get_or_insert_function("regmatch", 
                                           Type.function(VALUE, [VALUE]))
    eb = @func.create_block
    @main_block = eb.builder
    
    @rb_string_value_ptr = @module.external_function('rb_string_value_ptr', 
                                                     Type.function(P_CHAR, [P_VALUE]))
    @strlen = @module.external_function('strlen', Type.function(INT, [P_CHAR]))
  end
    
  def match(str)
    ExecutionEngine.run_function(@func, str)
  end
    
  def optimize
    bitout =  Tempfile.new('bit')
    @module.write_bitcode("#{bitout.path}")
    File.popen("/usr/local/bin/opt -O3 -f #{bitout.path}") {|fp|
      @module = LLVM::Module.read_bitcode(fp.read)
    }
    @func = @module.get_or_insert_function("regmatch", 
                                           Type.function(VALUE, [VALUE]))
  end
    
  def compile(restr)
    stm = make_stm(restr)
    rstr = @func.arguments[0]
    blocks = {}
    
    rstrp = @main_block.alloca(VALUE, 4)
    @main_block.store(rstr, rstrp)
    str = @main_block.call(@rb_string_value_ptr, rstrp)
    len = @main_block.call(@strlen, str)
    
    idxp = @main_block.alloca(INT, 4)
    @main_block.store(-1.llvm(INT), idxp)
    matchpos = @main_block.alloca(INT, 4)
    @main_block.store(1.llvm(INT), matchpos) # 1 means Ruby fixnum 0
    
    
    starray = stm.state
    starray.each_with_index do |elest, stn|
      blocks[stn] = @func.create_block
    end
    @main_block.br(blocks[0])
    
    starray.each_with_index do |elest, stn|
      @main_block.set_insert_point(blocks[stn])
      
      if stn == starray.size - 1 then
        mpos = @main_block.load(matchpos)
        mpos1 = @main_block.add(mpos, mpos)
        mpos2 = @main_block.add(mpos1, 1.llvm)
        @main_block.return(mpos2) # matched pos
      else
        idx = @main_block.load(idxp)
        if stn == 2 then
          @main_block.store(idx, matchpos)
        end
        idx = @main_block.add(idx, 1.llvm(INT))
        @main_block.store(idx, idxp)
        thenb = @func.create_block
        elseb = @func.create_block
        
        cmp = @main_block.icmp_sge(idx, len)
        @main_block.cond_br(cmp, thenb, elseb)
        @main_block.set_insert_point(thenb)
        @main_block.return(4.llvm)  # nil
        @main_block.set_insert_point(elseb)
        
        defstat = elest[256]
        elest.each do |key, val|
          if val != defstat then
            idx = @main_block.load(idxp)
            chp = @main_block.gep(str, idx)
            ch = @main_block.load(chp)
            cmp = @main_block.icmp_eq(ch, key.llvm(CHAR))
            
            elseb = @func.create_block
            
            @main_block.cond_br(cmp, blocks[val], elseb)
            @main_block.set_insert_point(elseb)
          end
        end
        
        if defstat then
          @main_block.br(blocks[defstat])
        else
          @main_block.return(4.llvm) # nil
        end
      end
    end
    @func
  end
end  

if __FILE__ == $0 then
#=begin
  require 'benchmark'
  
  ruby = "ruby"
  perl = "perl"
  dumy1 = "absadsafdsredddkflr"
  dumy2 = "sse3fdfds2#%666721"
  all = (dumy1 + dumy2 * 2 + dumy1) * 309000 + 
        ruby +  dumy1* 12 + dumy2 * 11 + perl + 
        (dumy1 + dumy2 * 2 + dumy1) * 320
  
  p all.size
  
  Benchmark.bm do |x|
    x.report("Ruby's          ") {
      (/ruby.*perl/ =~ all)
      (/perl.*ruby/ =~ all)
    }
    
    llvmatch1 = RegexpMatcherLLVM.new
    llvmatch1.compile(".*ruby.*perl")
    
    llvmatch2 = RegexpMatcherLLVM.new
    llvmatch2.compile(".*perl.*ruby")
    
    x.report("llvm without opt") {
      llvmatch1.match(all)
      llvmatch2.match(all)
    }
    
    llvmatch1.optimize
    llvmatch2.optimize
    
    x.report("llvm with opt   ") {
      llvmatch1.match(all)
      llvmatch2.match(all)
    }
  end
#=end
=begin
     llvmatch = MatcherLLVM.new
     st = reexp_comp(".*rrru*rby")
     p st
     llvmatch.compile(st)
     p llvmatch.match("aaarrrrurby")
=end
end
  
