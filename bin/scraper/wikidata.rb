#!/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'scraped'
require 'pry'

class Results < Scraped::JSON
  field :members do
    json[:results][:bindings].map { |result| fragment(result => Member).to_h }
  end
end

class Member < Scraped::JSON
  field :item do
    json.dig(:member, :value).to_s.split('/').last
  end

  field :name do
    json.dig(:name, :value)
  end

  # Wikidata => Official
  PARTY_MAP = {
    'ACT New Zealand' => 'ACT Party',
    'Green Party of Aotearoa New Zealand' => 'Green Party',
    'New Zealand National Party' => 'National Party',
    'New Zealand Labour Party' => 'Labour Party',
    'Maori Party' => 'Te Paati Māori',
  }

  field :party do
    PARTY_MAP.fetch(partyLabel, partyLabel)
  end

  field :electorate do
    json.dig(:areaLabel, :value).sub('List MP', 'List').sub('Mount ', 'Mt ')
  end

  private

  def partyLabel
    json.dig(:partyLabel, :value)
  end
end

WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql?format=json&query=%s'

memberships_query = <<SPARQL
  SELECT ?member ?name ?partyLabel ?areaLabel
  WHERE {
    ?member p:P39 ?ps .
    ?ps ps:P39 wd:Q18145518 ; pq:P2937 wd:Q85738447 .
    FILTER NOT EXISTS { ?ps pq:P582 ?end }
    OPTIONAL { ?ps pq:P4100 ?party }
    OPTIONAL { ?ps pq:P768 ?area }

    OPTIONAL { ?ps prov:wasDerivedFrom/pr:P1810 ?sourceName }
    OPTIONAL { ?member rdfs:label ?enLabel FILTER(LANG(?enLabel) = "en") }
    BIND(COALESCE(?sourceName, ?enLabel) AS ?name)
    SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
  }
  ORDER BY ?name
SPARQL

url = WIKIDATA_SPARQL_URL % CGI.escape(memberships_query)
headers = { 'User-Agent' => 'every-politican-scrapers/new-zealand-parliament' }
data = Results.new(response: Scraped::Request.new(url: url, headers: headers).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
