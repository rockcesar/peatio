# frozen_string_literal: true

module API
  module V2
    module Management
      class Orders < Grape::API
        helpers ::API::V2::OrderHelpers

        desc 'Returns orders' do
          @settings[:scope] = :read_orders
          success API::V2::Management::Entities::Order
        end
        params do
          optional :uid,
                   values: { value: ->(v) { Member.exists?(uid: v) }, message: 'management.orders.uid_doesnt_exist' },
                   desc: 'Filter order by market'
          optional :market,
                   values: { value: -> { ::Market.ids }, message: 'management.orders.market_doesnt_exist' },
                   desc: -> { API::V2::Management::Entities::Market.documentation[:id][:desc] }
          optional :state,
                   values: { value: -> { ::Order.state.values }, message: 'management.orders.invalid_state' },
                   desc: 'Filter order by state.'
          optional :ord_type,
                   values: { value: ::Order::TYPES, message: 'management.orders.invalid_ord_type' },
                   desc: 'Filter order by ord_type.'
        end
        post '/orders' do
          if params[:uid].present?
            member = Member.find_by(uid: params[:uid])
            params.except!(:uid).merge!(member_id: member.id) if member.present?
          end

          ransack_params = API::V2::Admin::Helpers::RansackBuilder.new(params)
                                                                  .eq(:ord_type, :state, :member_id)
                                                                  .translate(market: :market_id)
                                                                  .build

          search = Order.ransack(ransack_params)

          present search.result, with: API::V2::Management::Entities::Order
          status 200
        end

        desc 'Cancel specific order' do
          @settings[:scope] = :read_orders
          success API::V2::Management::Entities::Order
        end
        params do
          optional :id,
                   type: String,
                   allow_blank: false,
                   desc: -> { API::V2::Management::Entities::Order.documentation[:id][:desc] }
          optional :uuid,
                   values: { value: ->(v) { Order.exists?(uuid: v) }, message: 'management.orders.uuid_doesnt_exist' },
                   desc: -> { API::V2::Management::Entities::Order.documentation[:uuid][:desc] }
          exactly_one_of :id, :uuid
        end

        post '/orders/:id/cancel' do
          order_params = declared(params, include_missing: false)
          order = Order.find_by!(order_params)
          cancel_order(order)

          present order, with: API::V2::Management::Entities::Order
          status 200
        end
      end
    end
  end
end
