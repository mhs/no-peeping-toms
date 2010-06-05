module NoPeepingToms
  def self.included(base)
    unless base.included_modules.include?(NoPeepingToms::InstanceMethods)
      base.send :include, NoPeepingToms::InstanceMethods
      base.extend NoPeepingToms::ClassMethods
      base.alias_method_chain :update, :neighborhood_watch
      base.cattr_accessor :peeping_toms, :default_observers_enabled
      base.peeping_toms = [] # toms that are allowed to peep
    end

    base.enable_observers
  end

  module InstanceMethods
    def update_with_neighborhood_watch(*args)
      if self.class.default_observers_enabled || self.class.peeping_toms.include?(self)
        update_without_neighborhood_watch(*args)
      end
    end
  end
  
  module ClassMethods
    def method_added(name)
      super
      
      # The StateMachine 0.8.0 gem overrides the default #update method for observers
      # which means NoPeepingToms functionality gets ignored. This is to catch what
      # StateMachine does and then redirect it back to NoPeepingToms
      if !@update_with_multiple_args_added && name.to_s == "update_without_multiple_args"
        @update_with_multiple_args_added = true
        alias_method :update_without_neighborhood_watch, :update_with_multiple_args
        alias_method :update_with_multiple_args, :update_with_neighborhood_watch
      end
    end
    
    def with_observers(*observer_syms)
      self.peeping_toms = Array(observer_syms).map do |o| 
        o.respond_to?(:instance) ? o.instance : o.to_s.classify.constantize.instance
      end
      yield
    ensure
      self.peeping_toms.clear
    end

    def disable_observers
      self.default_observers_enabled = false
    end

    def enable_observers
      self.default_observers_enabled = true
    end
  end
end

ActiveRecord::Observer.send :include, NoPeepingToms