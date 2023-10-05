require 'spec_helper'

describe Graphlient::Client do
  include_context 'Github Client'

  it 'has a schema', vcr: { cassette_name: 'github/schema' } do
    expect(client.schema).to be_a Graphlient::Schema
  end

  it 'queries current user', vcr: { cassette_name: 'github/viewer' } do
    rc = client.query <<-GRAPHQL
      query {
        viewer {
          name
        }
      }
    GRAPHQL
    expect(rc.data.viewer.name).to eq 'Daniel Doubrovkine (dB.) @dblockdotorg'
  end

  it 'correctly sets the operation name & type', vcr: { cassette_name: 'github/viewer' } do
    expect {
      client.query <<-GRAPHQL
        query MyViewerAsOperationName {
          viewer {
            name
          }
        }
      GRAPHQL
    }.to instrument("query.graphql").with(hash_including(:operation_name=>"Graphlient__MyViewerAsOperationName", :operation_type=>"query"))
  end

  it 'queries with a parameter', vcr: { cassette_name: 'github/user' } do
    query = <<-GRAPHQL
      query($login: String!) {
        user(login: $login) {
          name
        }
      }
    GRAPHQL
    rc = client.query query, login: 'orta'
    expect(rc.data.user.name).to eq 'Orta'
  end
end
