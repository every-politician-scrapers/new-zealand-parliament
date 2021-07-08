#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'pry'
require 'scraped'

# TODO: fetch data from the individual member pages
class Legislature
  # details for an individual member
  class Member < Scraped::HTML
    field :id do
      td[1].css('a/@href').text.split('/').last
    end

    field :name do
      td[1].css('a').text.split(',').map(&:tidy).reverse.join(' ')
    end

    field :party do
      td[2].text.tidy
    end

    field :electorate do
      td[3].text.tidy
    end

    # This seems to be a 'last updated' rather than a start-date
    # field :start_date do
    # Date.parse(td[4].text.tidy).to_s
    # end

    private

    def td
      noko.css('td')
    end
  end

  # The page listing all the members
  class Members < Scraped::HTML
    decorator Scraped::Response::Decorator::CleanUrls

    field :members do
      noko.css('.tab__body .table--list tr').drop(1).map { |mp| fragment(mp => Member).to_h }
    end
  end
end

url = 'https://www.parliament.nz/en/mps-and-electorates/members-of-parliament/'
data = Legislature::Members.new(response: Scraped::Request.new(url: url).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
