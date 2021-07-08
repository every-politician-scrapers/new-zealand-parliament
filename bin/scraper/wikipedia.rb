#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'
require 'wikidata_ids_decorator'

require_relative './../../lib/unspan_all_tables'

require 'open-uri/cached'

class MembersPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :members do
    member_rows.map { |p| fragment(p => MemberRow) }.select(&:member?).map(&:to_h)
  end

  private

  def member_rows
    tables.flat_map { |table| table.xpath('.//tr[td]') }
  end

  # The set of 'foldable' tables after the 'Members' heading
  def tables
    noko.xpath('//h3[contains(.,"Members")]/following::table').chunk { |table| table.attr('role') == 'presentation' }.first.last
  end
end

class MemberRow < Scraped::HTML
  PARTIES = {
    'ACT New Zealand' => 'Q288838',
    'Green Party of Aotearoa New Zealand'  => 'Q1327761',
    'Labour' => 'Q1048192',
    'Māori Party' => 'Q1375170',
    'National' => 'Q204716',
  }.freeze

  def member?
    !td[4].text.to_i.zero?
  end

  field :name do
    name_link.text.tidy
  end

  field :wikidata do
    name_link.attr('wikidata')
  end

  field :party do
    noko.xpath('ancestor::table//th').map(&:text).first.split('(').first.tidy
  end

  field :party_wikidata do
    PARTIES[party]
  end

  field :constituency do
    return 'List' if td[3].css('a').empty?

    td[3].css('a').text.tidy
  end

  field :constituency_wikidata do
    return 'Q3798091' if constituency == 'List'

    td[3].css('a/@wikidata').text
  end

  private

  def td
    noko.css('td')
  end

  def name_link
    td[2].css('a').first
  end
end

url = 'https://en.wikipedia.org/wiki/53rd_New_Zealand_Parliament'
data = MembersPage.new(response: Scraped::Request.new(url: url).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
