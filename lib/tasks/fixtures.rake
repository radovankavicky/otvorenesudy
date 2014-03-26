# encoding: utf-8

namespace :fixtures do
  namespace :db do
    desc "Drops, creates, migrates and loads seed data into the database"
    task rebuild: :environment do
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      Rake::Task['db:migrate'].invoke
      Rake::Task['db:seed'].invoke
    end

    desc "Setups small database with production data (drops existing database)"
    task setup: :environment do
      Rake::Task['fixtures:db:rebuild'].invoke
      Rake::Task['fixtures:db:seed'].invoke
      Rake::Task['fixtures:db:hearings'].invoke
      Rake::Task['fixtures:db:decrees'].invoke
    end

    desc "Seeds database with necessary data"
    task seed: :environment do
      Rake::Task['crawl:courts'].invoke
      Rake::Task['crawl:judges'].invoke

      Rake::Task['process:paragraphs'].invoke
    end

    desc "Crawls small amount hearings"
    task hearings: :environment do
      Rake::Task['crawl:hearings:civil'].invoke    1, 20
      Rake::Task['crawl:hearings:criminal'].invoke 1, 20
      Rake::Task['crawl:hearings:special'].invoke  1, 20
    end

    desc "Crawls small amount of decrees"
    task :decrees, [:reverse] => :environment do |_, args|
      args.with_defaults reverse: false

      codes = DecreeForm.order(:code).all

      raise "No decree form codes found." if codes.empty?

      codes.reverse! if args[:reverse]

      codes.each do |form|
        Rake::Task['crawl:decrees'].reenable
        Rake::Task['crawl:decrees'].invoke form.code, 1, 4
      end
    end

    desc "Prints basic statistics about the database"
    task stat: :environment do
      puts "Courts: #{Court.count}"
      puts "Judges: #{Judge.count}"
      puts
      puts "Paragraphs: #{Paragraph.count}"
      puts
      puts "Hearings total:    #{Hearing.count}"
      puts "Hearings civil:    #{CivilHearing.count}"
      puts "Hearings criminal: #{CriminalHearing.count}"
      puts "Hearings special:  #{SpecialHearing.count}"
      puts
      puts "Decrees total:  #{Decree.count}"

      DecreeForm.order(:code).all.each do |form|
        puts "Decrees form #{form.code}: #{Decree.where('decree_form_id = ?', form.id).count}"
      end

      puts
      puts "Court expenses:              #{CourtExpense.count}"
      puts "Court statistical summaries: #{CourtStatisticalSummary.count}"
      puts
      puts "Judge desigantions:          #{JudgeDesignation.count}"
      puts "Judge property declarations: #{JudgePropertyDeclaration.count}"
      puts "Judge statistical summaries: #{JudgeStatisticalSummary.count}"
    end
  end

  namespace :export do
    desc "Export judge property declarations and some other related data into CSVs"
    task :judge_property_declarations, [:path] => :environment do |_, args|
      include Core::Pluralize
      include Core::Output

      path = args[:path] || 'tmp'

      FileUtils.mkpath path

      file            = File.open File.join(path, 'judge-property-declarations.csv'), 'w'
      file_incomes    = File.open File.join(path, 'judge-property-declarations-incomes.csv'), 'w'
      file_people     = File.open File.join(path, 'judge-property-declarations-people.csv'), 'w'
      file_statements = File.open File.join(path, 'judge-property-declarations-statements.csv'), 'w'

      data  = [:uri, :judge_name]
      data += [:court_name, :year]
      data += [:category]
      data += [:description]
      data += [:cost, :share_size, :acquisition_date]
      data += [:acquisition_reason, :ownership_form, :change]

      file.write(data.join("\t") + "\n")

      Judge.order(:name).all.each do |judge|
        print "Exporting declaration properties for judge #{judge.name} ... "

        judge.property_declarations.each do |declaration|
          declaration.lists.each do |list|
            list.items.each do |property|
              data  = [declaration.uri, judge.name]
              data += [declaration.court.name, declaration.year]
              data += [list.category.value]
              data += [property.description]
              data += [property.cost, property.share_size, property.acquisition_date]
              data << (property.acquisition_reason.nil? ? '' : property.acquisition_reason.value)
              data << (property.ownership_form.nil?     ? '' : property.ownership_form.value)
              data << (property.change.nil?             ? '' : property.change.value)

              file.write(data.join("\t") + "\n")
            end
          end

          declaration.incomes.each do |income|
            data  = [declaration.uri, judge.name]
            data += [declaration.court.name, declaration.year]
            data += [income.description, income.value]

            file_incomes.write(data.join("\t") + "\n")
          end

          declaration.related_people.each do |person|
            data  = [declaration.uri, judge.name]
            data += [declaration.court.name, declaration.year]
            data += [person.name, person.institution, person.function]

            file_people.write(data.join("\t") + "\n")
          end

          declaration.statements.each do |statement|
            data  = [declaration.uri, judge.name]
            data += [declaration.court.name, declaration.year]
            data += [statement.value]

            file_statements.write(data.join("\t") + "\n")
          end
        end

        puts "done"
      end

      file.close
      file_incomes.close
      file_people.close
      file_statements.close
    end

    desc "Export judge related people with metadata about judge position"
    task judge_related_people: :environment do
      file = File.open Rails.root.join('tmp', 'judge-related-people.csv'), 'w'

      data  = [:judge_id, :judge_name, :court, :court_address, :court_latitude, :court_longitude, :position]
      data += [:person_id, :person_name, :court, :court_address, :court_latitude, :court_longitude, :position]

      file.write(data.join("\t") + "\n")

      Judge.find_each do |judge|
        related_people = judge.related_people.where(:'judge_property_declarations.year' => 2012)

        next unless related_people.any?

        converter = lambda do |j|
          employment = j.employments.first
          court      = employment.court
          position   = employment.judge_position

          [j.id, j.name, court.name, court.address, court.latitude, court.longitude, position.try(:value)]
        end

        related_people.each do |person|
          person = person.to_judge

          next unless person

          data  = converter.call(judge)
          data += converter.call(person)

          file.write(data.join("\t") + "\n")
        end
      end

      file.close
    end

    desc "Export some statistics from judge statistical summaries"
    task judge_statistics: :environment do
      file = File.open Rails.root.join('tmp', 'judge-statistics.csv'), 'w'

      years   = [2012, 2011]
      keys    = ['rozhodnuté', 'rozhodnuté-meritórne', 'odvolania-potvrdené', 'odvolania-zmenené', 'odvolania-zrušené', 'odvolania-odmietnuté']
      agendas = ['C', 'Cb', 'P', 'T']

      data = ['sudca']

      years.each do |year|
        data << "súd-#{year}"

        keys.each do |key|
          agendas.each do |agenda|
            data << "#{key}-#{agenda}-#{year}"
          end
        end
      end

      file.write(data.join("\t") + "\n")

      Judge.find_each do |judge|
        print "Processing #{judge.name} ... "

        summaries = []

        years.each do |year|
          summaries << judge.statistical_summaries.where(year: year).first
        end

        if summaries.blank?
          puts "done (no summaries)"
        end

        data = [judge.name]

        summaries.each do |summary|
          if summary.nil?
            (keys.size * agendas.size + 1).times { data << :missing }

            next
          end

          data << [summary.court.name]

          table = summary.tables.by_name('R').first

          ['sv_Pocet1', 'sv_Pocet2'].each do |row|
            agendas.each do |agenda|
              cell = StatisticalTableCell.of(table, agenda,  row)
              data << (cell ? cell.value : :missing)
            end
          end

          table = summary.tables.by_name('O').first

          ['sv_Pocet1', 'sv_Pocet2', 'sv_Pocet3', 'sv_Pocet4'].each do |row|
            agendas.each do |agenda|
              cell = StatisticalTableCell.of(table, agenda, row)
              data << (cell ? cell.value : :missing)
            end
          end
        end

        file.write(data.join("\t") + "\n")

        puts "done (#{summaries.size} summaries)"
      end

      file.close
    end
  end

  namespace :hearings do
    desc "Loads remaining stored hearings into database"
    task :load, [:hearing_type] => :environment do |_, args|
      include Core::Injector
      include Core::Pluralize
      include Core::Output

      type = args[:hearing_type] || raise("Hearing type not set.")

      storage = inject JusticeGovSk::Storage, prefix: type.titlecase, implementation: :Hearing, suffix: :Page
      crawler = inject JusticeGovSk::Crawler, prefix: type.titlecase, implementation: :Hearing

      storage.batch do |entries, bucket|
        puts "Loading #{pluralize entries.size, "#{type} hearing"} from bucket #{bucket}."

        n = 0

        entries.each do |entry|
          uri = JusticeGovSk::URL.path_to_url entry

          crawler.crawl uri

          n += 1
        end

        puts "finished (#{pluralize n, 'hearing'})"
      end
    end

    desc "Anonymizes all defendants"
    task :anonymize, [:hearing_id] => :environment do |_, args|
      include Core::Identify
      include Core::Pluralize
      include Core::Output

      include JusticeGovSk::Helper::Normalizer

      hearing = Hearing.find args[:hearing_id]

      abort "Already anonymized" if hearing.anonymized
      abort "No defendants" if hearing.defendants.none?

      hearing.defendants.each do |defendant|
        others = defendant.name.sub!(/\s+a\s+spol\.\z/i, '')
        parts  = partition_person_name(defendant.name)
        name   = "#{parts[:prefix]} #{[parts[:first], parts[:middle], parts[:last]].reject(&:blank?).map { |s| "#{s.first}. " }.join.strip}, #{parts[:suffix]}"
        name   = name.sub(/\,\s*\z/, '')
        name  += ' a spol.' if others
        name   = name.strip.squeeze ' '

        puts "#{identify defendant} '#{defendant.name}' -> '#{name}'"

        defendant.name = name
        defendant.save!
      end

      hearing.anonymized = true
      hearing.save!
    end
  end

  namespace :decrees do
    desc "Loads remaining stored decrees into database"
    task :load, [:decree_form_code, :offset, :limit] => :environment do |_, args|
      args.with_defaults safe: false

      options = args.dup

      offset = options[:offset].blank? ? 1 : options[:offset].to_i
      limit  = options[:limit].blank? ? nil : options[:limit].to_i

      request, lister = JusticeGovSk.build_request_and_lister Decree, options

      crawler = JusticeGovSk.build_crawler Decree, options
      storage = JusticeGovSk::Storage::DecreePage.instance

      JusticeGovSk.run_lister lister, request, options do
        lister.crawl(request, offset, limit) do |uri|
          unless storage.contains? JusticeGovSk::URL.url_to_path(uri, :html)
            puts "Decree page not downloaded, crawling skipped."
            next
          end

          if Decree.where(uri: uri).first
            puts "Decree already exists in database, crawling skipped."
            next
          end

          JusticeGovSk.run_crawler crawler, uri, options
        end
      end
    end

    desc "Extract missing images of decree documents"
    task :extract_images, [:filter, :override] => :environment do |_, args|
      include Core::Pluralize
      include Core::Output

      args.with_defaults filter: '', override: false

      document_storage = JusticeGovSk::Storage::DecreeDocument.instance
      image_storage    = JusticeGovSk::Storage::DecreeImage.instance

      document_storage.batch do |entries, bucket|
        unless bucket.start_with? args[:filter]
          puts "Bucket #{bucket} matches skip filter, moving on next bucket."
          next
        end

        print "Running image extraction for bucket #{bucket}, "
        print "#{pluralize entries.size, 'document'}, "
        puts  "#{args[:override] ? 'overriding' : 'skipping'} already extracted."

        n = 0

        entries.each do |entry|
          next unless args[:override] || !image_storage.contains?(entry)

          options = { output: image_storage.path(entry) }

          JusticeGovSk::Extractor::Image.extract document_storage.path(entry), options

          n += 1
        end

        puts "finished (#{pluralize n, 'document'} extracted)"
      end
    end
  end

  namespace :proceedings do
    desc 'Extract random finished proceedings with treshold'
    task :extract, [:limit] => :environment  do |_, args|
      limit = args[:limit] ? args[:limit].to_i : 1000
      count = 0

      time = Time.now

      puts "time\ttimestamp"
      puts "#{time}\t#{time.to_i}"

      columns = []

      columns << 'id'
      columns << 'probably_closed'
      columns << 'duration'
      columns << 'last_court_type'
      columns << 'judges_designations_duration'

      columns << 'courts.ids'
      columns << 'courts.size'
      columns << 'judges.ids'
      columns << 'judges.size'

      columns << 'proposers.ids'
      columns << 'proposers.size'
      columns << 'opponents.ids'
      columns << 'opponents.size'
      columns << 'defendants.ids'
      columns << 'defendants.size'

      columns << 'events.ids'
      columns << 'events.size'
      columns << 'hearings.ids'
      columns << 'hearings.size'
      columns << 'decrees.ids'
      columns << 'decrees.size'
      columns << 'decrees.pages.size'

      columns << 'hearings.forms.ids'
      columns << 'hearings.forms.size'
      columns << 'hearings.sections.ids'
      columns << 'hearings.sections.size'
      columns << 'hearings.subjects.ids'
      columns << 'hearings.subjects.size'
      columns << 'hearings.type.ids'
      columns << 'hearings.type.size'

      columns << 'decrees.forms.ids'
      columns << 'decrees.forms.size'
      columns << 'decrees.legislation_areas.ids'
      columns << 'decrees.legislation_areas.size'
      columns << 'decrees.legislation_subareas.ids'
      columns << 'decrees.legislation_subareas.size'
      columns << 'decrees.legislations.ids'
      columns << 'decrees.legislations.size'
      columns << 'decrees.natures.ids'
      columns << 'decrees.natures.size'

      courts_ids = Court.order(:id).pluck(:id)
      judges_ids = Judge.order(:id).pluck(:id)

      courts_ids.each { |id| columns << "court.#{id}" }
      judges_ids.each { |id| columns << "judge.#{id}" }

      puts columns.join("\t")

      Proceeding.order('random()').find_each do |proceeding|
        break if count >= limit

        # select only probably closed proceedings with at least one hearing and one decree
        next unless proceeding.probably_closed? && proceeding.events.map(&:class).uniq == [Hearing, Decree]

        count += 1

        data = []

        proceeding_courts_ids = proceeding.courts.map(&:id).uniq.sort
        proceeding_judges_ids = proceeding.judges.map(&:id).uniq.sort

        proceeding_proposers_ids  = Proposer.joins(:hearing).where(:'hearings.proceeding_id' => proceeding.id).pluck('proposers.id').uniq
        proceeding_opponents_ids  = Opponent.joins(:hearing).where(:'hearings.proceeding_id' => proceeding.id).pluck('opponents.id').uniq
        proceeding_defendants_ids = Defendant.joins(:hearing).where(:'hearings.proceeding_id' => proceeding.id).pluck('defendants.id').uniq

        data << proceeding.id
        data << proceeding.probably_closed?
        data << proceeding.duration(time)
        data << proceeding.decrees.order('date desc').last.court.type.id # TODO (smolnar) use comparison on court.type for determining the most significant court type
        data << proceeding.judges.map(&:designations).flatten.map { |designation| designation.duration(time) }.sum.round

        data << proceeding_courts_ids.join(',')
        data << proceeding_courts_ids.size
        data << proceeding_judges_ids.join(',')
        data << proceeding_judges_ids.size

        data << proceeding_proposers_ids.join(',')
        data << proceeding_proposers_ids.size
        data << proceeding_opponents_ids.join(',')
        data << proceeding_opponents_ids.size
        data << proceeding_defendants_ids.join(',')
        data << proceeding_defendants_ids.size

        data << proceeding.events.map(&:id).uniq.join(',')
        data << proceeding.events.uniq.size
        data << proceeding.hearings.pluck('hearings.id').uniq.join(',')
        data << proceeding.hearings.uniq.size
        data << proceeding.decrees.pluck('decrees.id').uniq.join(',')
        data << proceeding.decrees.uniq.size
        data << proceeding.decrees.map(&:pages).flatten.uniq.size

        data << proceeding.hearings.pluck('hearing_form_id').uniq.join(',')
        data << proceeding.hearings.pluck('hearing_form_id').uniq.size
        data << proceeding.hearings.pluck('hearing_section_id').uniq.join(',')
        data << proceeding.hearings.pluck('hearing_section_id').uniq.size
        data << proceeding.hearings.pluck('hearing_subject_id').uniq.join(',')
        data << proceeding.hearings.pluck('hearing_subject_id').uniq.size
        data << proceeding.hearings.pluck('hearing_type_id').uniq.join(',')
        data << proceeding.hearings.pluck('hearing_type_id').uniq.size

        data << proceeding.decrees.pluck('decree_form_id').uniq.join(',')
        data << proceeding.decrees.pluck('decree_form_id').uniq.size
        data << proceeding.decrees.pluck('legislation_area_id').uniq.join(',')
        data << proceeding.decrees.pluck('legislation_area_id').uniq.size
        data << proceeding.decrees.pluck('legislation_subarea_id').uniq.join(',')
        data << proceeding.decrees.pluck('legislation_subarea_id').uniq.size
        data << proceeding.decrees.joins(:legislations).pluck('legislations.id').uniq.join(',')
        data << proceeding.decrees.joins(:legislations).pluck('legislations.id').uniq.size
        data << proceeding.decrees.joins(:naturalizations).pluck('decree_nature_id').uniq.join(',')
        data << proceeding.decrees.joins(:naturalizations).pluck('decree_nature_id').uniq.size

        courts_ids.each { |id| data << (proceeding_courts_ids.include?(id) ? 1 : 0) }
        judges_ids.each { |id| data << (proceeding_judges_ids.include?(id) ? 1 : 0) }

        # TODO multiple season? how to represent

        puts data.join("\t")
      end
    end
  end
end
