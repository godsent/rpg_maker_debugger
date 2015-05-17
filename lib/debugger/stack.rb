# своровано у Ёльфа
# код, став€щий в соответствие номеру скрипта его название
if RUBY_VERSION.to_f==1.9
  scripts=load_data('Data/Scripts.rvdata2')
else
  scripts=load_data('Data/Scripts.rxdata')
end
$script_names=[]
scripts.each{ |item|
	if RUBY_VERSION.to_f==1.9
		$script_names+=[item[1]]
	else
		text=item.to_s.match(/[\d]+([\w_\d]+)/)[1]
		$script_names+=[ text.gsub(/x$/){''} ]
	end
}


module Kernel
	
	def call_stack
		stack = caller
		stack.each {|line| 
			# skip first lines connected to debugger itself
			next if line =~ /\/lib\/debugger/
			line.gsub!(/\{(\d+)\}/) {|s| $script_names[$1.to_i] + " " } 
			p line
		}
		return nil
	end

end
