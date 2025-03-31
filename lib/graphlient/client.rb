module Graphlient
  class Client
    attr_accessor :uri, :options

    class InvalidConfigurationError < StandardError; end

    def initialize(url, options = {}, &_block)
      @url = url
      @options = options.dup
      raise_error_if_invalid_configuration!
      yield self if block_given?
    end

    def parse(query_str = nil, &block)
      query_str ||= Graphlient::Query.new do
        instance_eval(&block)
      end
      client.parse(query_str.to_s)
    rescue GraphQL::Client::Error => e
      raise Graphlient::Errors::ClientError, e.message
    end

    def execute(query, variables = nil)
      query_params = {}
      query_params[:context] = @options if @options
      query_params[:variables] = variables if variables
      rc = client.query(parse_query(query), **query_params)
      raise Graphlient::Errors::GraphQLError, rc if rc.errors.any?
      # see https://github.com/github-community-projects/graphql-client/pull/132
      # see https://github.com/exAspArk/graphql-errors/issues/2
      raise Graphlient::Errors::ExecutionError, rc if errors_in_result?(rc)
      rc
    rescue GraphQL::Client::Error => e
      raise Graphlient::Errors::ClientError, e.message
    end

    def query(query_or_variables = nil, variables = nil, &block)
      if block_given?
        execute(parse(&block), query_or_variables)
      else
        execute(query_or_variables, variables)
      end
    end

    def http_adapter_class
      options[:http] || Adapters::HTTP::FaradayAdapter
    end

    def http(&block)
      adapter_options = { headers: @options[:headers], http_options: @options[:http_options] }

      @http ||= http_adapter_class.new(@url, adapter_options, &block)
    end

    def schema
      @schema ||= options[:schema] || Graphlient::Schema.new(http, schema_path)
    end

    private

    def raise_error_if_invalid_configuration!
      raise InvalidConfigurationError, 'schema_path and schema cannot both be provided' if options.key?(:schema_path) && options.key?(:schema)
    end

    def schema_path
      return options[:schema_path].to_s if options[:schema_path]
    end

    def client
      @client ||= GraphQL::Client.new(schema: schema.graphql_schema, execute: http).tap do |client|
        client.allow_dynamic_queries = @options.key?(:allow_dynamic_queries) ? options[:allow_dynamic_queries] : true
      end
    end

    def errors_in_result?(response)
      response.data && response.data.errors && response.data.errors.all.any?
    end

    def parse_query(query)
      return query unless query.is_a?(String)

      query = client.parse(query)
      return query if query.is_a?(GraphQL::Client::OperationDefinition)
      
      query = query.const_get(query.constants.first)
      patch_operation_name(query)
      query
    end

    def patch_operation_name(query)
      query.instance_eval do
        def name
          super.gsub(/#<Module:(0x[0-9a-f]+)>/, 'Graphlient')
        end
      end
    end
  end
end
