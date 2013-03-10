module Hound
  module Model

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Tell Hound to track this models actions.
      #
      # options - a Hash of configuration options.
      def hound(options = {})
        send :include, InstanceMethods

        has_many :actions,
          as: 'actionable',
          class_name: 'Hound::Action'

        options[:actions] ||= Hound.config.actions
        options[:actions] = Array(options[:actions]).map(&:to_s)

        class_attribute :hound_options
        self.hound_options = options.dup

        attr_accessor :hound

        # Add action hooks
        after_create :hound_create if options[:actions].include?('create')
        before_update :hound_update if options[:actions].include?('update')
        after_destroy :hound_destroy if options[:actions].include?('destroy')
      end
    end

    module InstanceMethods

      # Return all actions in provided date.
      def actions_for_date(date)
        actions.where(created_at: date)
      end

      # Returns true if hound is enabled on this instance.
      def hound?
        hound != false
      end

      private

      def hound_create
        return unless hound?
        attributes = default_attributes.merge(action: 'create')
        actions.create! attributes
        enforce_limit
      end

      def hound_update
        return unless hound?
        attributes = default_attributes.merge(action: 'update')
        attributes.merge!(changeset: changes)
        actions.create! attributes
        enforce_limit
      end

      def hound_destroy
        return unless hound?
        attributes = default_attributes.merge(action: 'destroy')
        attributes.merge!(
          actionable_id: self.id,
          actionable_type: self.class.base_class.name)
        Hound::Action.create(attributes)
        enforce_limit
      end

      def default_attributes
        {
          user_id: Hound.store[:current_user_id]
        }
      end

      def enforce_limit
        limit = self.class.hound_options[:limit]
        limit ||= Hound.config.limit
        if limit and actions.size > limit
          good_actions = actions.order('created_at DESC').limit(limit)
          actions.where('id NOT IN (?)', good_actions.map(&:id)).delete_all
        end
      end

    end

  end
end