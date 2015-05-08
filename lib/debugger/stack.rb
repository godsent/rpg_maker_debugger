$call_stack = []

set_trace_func proc { |event, file, line, id, binding, classname|
	unless classname.to_s =~ /Debugger/
		if event == "call"
			method_name = binding.eval "__method__"
			args = binding.eval "method(__method__).parameters"
			args.each { |arg|
				
			}
			$call_stack.push(classname.to_s + ":" + method_name.to_s + " " + args.inspect)
		elsif event == "return"
			$call_stack.pop
		end
	end
}