# frozen_string_literal: true

describe API::V2::Management::Orders, type: :request do
  let(:member1) { create(:member, :level_3) }
  let(:member2) { create(:member, :level_3) }
  let(:signers) { %i[alex jeff] }

  before do
    defaults_for_management_api_v1_security_configuration!
    management_api_v1_security_configuration.merge! \
      scopes: {
        read_orders: { permitted_signers: %i[alex jeff], mandatory_signers: %i[alex] }
      }

    create(:order_bid, :btcusd, member: member1, state: Order::CANCEL)
    create(:order_ask, :btcusd, member: member1, state: Order::WAIT, updated_at: Time.now + 10)
    create(:order_ask, :btceth, member: member1, state: Order::DONE)
    create(:order_bid, :btcusd, member: member2, state: Order::CANCEL)
    create(:order_ask, :btcusd, member: member2, state: Order::WAIT, updated_at: Time.now + 10)
    create(:order_ask, :btceth, member: member2, state: Order::DONE)
  end

  describe 'read orders' do
    def request
      post_json '/api/v2/management/orders', multisig_jwt_management_api_v1({ data: data }, *signers)
    end

    let(:data) { {} }

    it 'returns all orders on the platform' do
      request

      expect(response).to have_http_status 200
      expect(response_body.count).to eq(Order.count)
    end

    context 'by member' do
      let(:data) do
        {
          uid: member1.uid
        }
      end

      it 'returns only member orders' do
        request

        expect(response).to have_http_status 200
        expect(response_body.pluck('member_id').uniq).to eq([member1.id])
      end
    end

    context 'by member, market, state and order type' do
      let(:data) do
        {
          uid: member1.uid,
          market: 'btcusd',
          state: 'wait',
          ord_type: 'limit'
        }
      end

      it 'returns only member orders on specific market with specific state and order type' do
        request

        expect(response).to have_http_status 200
        expect(response_body.pluck('member_id').uniq).to eq([member1.id])
        expect(response_body.pluck('state').uniq).to eq(['wait'])
        expect(response_body.pluck('market').uniq).to eq(['btcusd'])
        expect(response_body.pluck('ord_type').uniq).to eq(['limit'])
      end
    end

    context 'invalid params' do
      context 'member_uid' do
        it 'returns status 422 and error' do
          data[:uid] = 'invalid_uid'
          request

          expect(response).to have_http_status(422)
        end
      end

      context 'market' do
        it 'returns status 422 and error' do
          data[:market] = 'invalid_market'
          request

          expect(response).to have_http_status(422)
        end
      end

      context 'state' do
        it 'returns status 422 and error' do
          data[:state] = 'invalid_state'
          request

          expect(response).to have_http_status(422)
        end
      end

      context 'ord_type' do
        it 'returns status 422 and error' do
          data[:ord_type] = 'invalid_ord_type'
          request

          expect(response).to have_http_status(422)
        end
      end
    end
  end
end
