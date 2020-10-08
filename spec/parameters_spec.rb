require 'spec_helper'

RSpec.describe ExplicitParameters::Parameters do
  let :definition do
    ExplicitParameters::Parameters.define(:test) do
      requires :id, Integer, numericality: {greater_than: 0}
      accepts :name, String
      accepts :title, String, default: 'Untitled'
    end
  end

  let :parameters do
    {
      'id' => '42',
      'name' => 'George',
      'unexpected' => 'parameter',
    }
  end

  let(:params) { definition.parse!(parameters.with_indifferent_access) }

  it 'casts parameters to the declared type' do
    expect(params.id).to be == 42
  end

  it 'provides the default if the parameter is missing' do
    expect(params.title).to be == 'Untitled'
  end

  it 'ignores unexpected parameters during iteration' do
    params.each do |name, value|
      expect(name).to_not be == 'unexpected'
    end
  end

  it 'ignores unexpected parameters when converted to hash' do
    expect(params.to_hash.keys).to be == %i(id name)
  end

  it 'ignores unexpected parameters when converted to hash with string keys' do
    expect(params.stringify_keys.keys).to be == %w(id name)
  end

  it '#reject returns a hash' do
    expect(params.reject { false }).to be == {id: 42, name: 'George'}
  end

  it 'allows access to raw parameters when accessed like a Hash' do
    expect(params[:id]).to be == '42'
    expect(params[:unexpected]).to be == 'parameter'
  end

  it 'can perform any type of active model validations' do
    message = {errors: {id: ['must be greater than 0']}}.to_json
    expect {
      definition.parse!('id' => -1)
    }.to raise_error(ExplicitParameters::InvalidParameters, message)
  end

  context "when non-required parameter is nil" do
    let :parameters do
      {
        'id' => '42',
        'name' => nil
      }
    end

    it "accepts it" do
      expect(params[:id]).to be == '42'
    end
  end

  context 'with nested parameters' do
    let :definition do
      ExplicitParameters::Parameters.define(:nested) do
        requires :address do
          requires :street, String
          requires :city, String
        end
      end
    end

    let :parameters do
      {
        'address' => {
          'street' => '3575 St-Laurent',
          'city' => 'Montréal',
        }
      }
    end

    it 'parses expose the nested hash as a `Parameters` instance' do
      expect(params.address).to be_an ExplicitParameters::Parameters
    end

    it 'parses nested hashes' do
      expect(params.address.street).to be == '3575 St-Laurent'
      expect(params.address.city).to be == 'Montréal'
    end

    it 'reports missing attributes' do
      message = {errors: {address: ['is required']}}.to_json
      expect {
        definition.parse!({})
      }.to raise_error(ExplicitParameters::InvalidParameters, message)
    end
  end

  context 'with list of parameters' do
    let :definition do
      ExplicitParameters::Parameters.define(:nested) do
        accepts :addresses, Array do
          requires :street, String
          requires :city, String
        end
      end
    end

    let :parameters do
      {
        'addresses' => [
          {
            'street' => '3575 St-Laurent',
            'city' => 'Montréal',
          }
        ]
      }
    end

    it 'the exposed parameter is an Array' do
      expect(params.addresses).to be_an Array
      expect(params.addresses.size).to be == 1
    end

    it 'parses nested hashes' do
      expect(params.addresses.first.street).to be == '3575 St-Laurent'
      expect(params.addresses.first.city).to be == 'Montréal'
    end

    context 'when required' do
      let :definition do
        ExplicitParameters::Parameters.define(:nested) do
          requires :addresses, Array do
            requires :street, String
            requires :city, String
          end
        end
      end

      it 'reports missing attributes' do
        message = {errors: {addresses: ['is required']}}.to_json
        expect {
          definition.parse!({})
        }.to raise_error(ExplicitParameters::InvalidParameters, message)
      end

      it 'considers empty arrays as missing' do
        message = {errors: {addresses: ['is required']}}.to_json
        expect {
          params = definition.parse!({'addresses' => []})
          p params.addresses
        }.to raise_error(ExplicitParameters::InvalidParameters, message)
      end
    end
  end
end
