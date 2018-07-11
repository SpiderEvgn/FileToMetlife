class Profile < ApplicationRecord
  require 'csv'

  validates :firstname, presence: true
  validates :lastname, presence: true
  validates :id_num, presence: true, uniqueness: true
  validates :cellphone, presence: true, uniqueness: true

  COMPOUND_NAME = %W[
    欧阳 太史 端木 上官 司马 东方 独孤 南宫 万俟 闻人 
    夏侯 诸葛 尉迟 公羊 赫连 澹台 皇甫 宗政 濮阳 公冶 
    太叔 申屠 公孙 慕容 仲孙 钟离 长孙 宇文 司徒 鲜于 
    司空 闾丘 子车 亓官 司寇 巫马 公西 颛孙 壤驷 公良 
    漆雕 乐正 宰父 谷梁 拓跋 夹谷 轩辕 令狐 段干 百里 
    呼延 东郭 南门 羊舌 微生 公户 公玉 公仪 梁丘 公仲 
    公上 公门 公山 公坚 左丘 公伯 西门 公祖 第五 公乘 
    贯丘 公皙 南荣 东里 东宫 仲长 子书 子桑 即墨 达奚 
    褚师 吴铭]

  FILE_HEADER = %W[
    姓
    名
    性别
    生日
    身份证
    邮箱
    电话
    单位名称
    职业
    职级
    省份
    城市
    地址
    邮编
    PC139
    PC150
    PC151
    PC167
  ]

  def profile_row_info
    [
      self.firstname,
      self.lastname,
      self.gender,
      self.birthday,
      self.id_num,
      self.email,
      self.cellphone,
      self.employer,
      self.occupation,
      self.position,
      self.province,
      self.city,
      self.address,
      self.zipcode,
      self.PC139,
      self.PC150,
      self.PC151,
      self.PC167
    ]
  end

  def check_response(response)
    reg1 = /Flag&gt;(.*)&lt;\/Flag/
    reg1.match(response)
    if $1.include?('FALSE')
      reg2 = /Message&gt;(.*)&lt;\/Message/
      reg2.match(response)
    end
    return $1
  end

  def full_name
    self.firstname + self.lastname
  end

  class << self
    def import_csv(file_name)
      content = CSV.read('/app/import_data/' + file_name + '.csv')
      content.shift
      content.each do |row|
        Profile.create(
          firstname: row[0],
          lastname: row[1],
          gender: row[2],
          birthday: row[3],
          id_num: row[4],
          email: row[5],
          cellphone: row[6],
          employer: row[7],
          occupation: row[8],
          position: row[9],
          province: row[10],
          city: row[11],
          address: row[12],
          zipcode: row[13]
          )
      end
    end

    def import_xlsx(file_name, is_store=nil)
      content = Roo::Spreadsheet.open('/app/import_data/' + file_name + '.xlsx')
      data_all = content.sheet('Sheet1').to_a
      data_all.shift
      # 去空格
      data_all.each do |row|
        11.times do |index|
          row[index] ? row[index] = row[index].to_s.gsub(' ','') : row[index]
          row[index] ? row[index] = row[index].to_s.gsub('　','') : row[index]
          # 手机号去 -
          if index == 3
            row[index] = row[index].to_s.gsub('-','')
            row[index] = row[index].to_s.gsub('－','')
          end
        end
      end

      correctProfiles = []
      errorProfiles = []
      row_repeat_checkpoint = 0

      # 姓名,身份证,邮箱,电话,单位名称,职业,职级,省份,城市,地址,邮编
      # 当前表内数据查重
      data_all.each_with_index do |row, index|
        data_all[index+1..-1].each do |next_row|
          # 判断是否已经重复，则跳过
          if next_row[11]
            next
          end
          if row[1] == next_row[1]
            next_row[11] = '表内：身份证与'+row[0]+'重复'
            row_repeat_checkpoint = 1
          elsif row[3] == next_row[3]
            next_row[11] = '表内：手机号与'+row[0]+'重复'
            row_repeat_checkpoint = 1
          end
        end
        if row_repeat_checkpoint == 1
          row[11] = '表内：数据重复'
        end
        row_repeat_checkpoint = 0
      end # data_all.each_with_index

      # 去掉重复数据后过滤到 data
      data = []
      data_all.each do |row|
        if row[11]
          errorProfiles << [row[0], row[1], row[3], row[11]]
        else
          data << row
        end
      end # data_all.each

      # 初始化 时间（用于匹配生日）和 姓名
      time = Time.new
      firstname = ''
      lastname = ''
      # 在当前表去重后的 data 中做数据验证 并 存入数据库
      data.each do |row|
        fullname   = row[0]
        id_num     = row[1]
        email      = row[2]
        cellphone  = row[3]
        employer   = row[4]
        occupation = row[5]
        position   = row[6]
        province   = row[7]
        city       = row[8]
        address    = row[9]
        zipcode    = row[10]
        # 身份证例子: 512928197108036312
        birthday = id_num ? id_num[6..13] : id_num
        year  = id_num ? id_num[6..9] : id_num
        month = id_num ? id_num[10..11] : id_num
        day   = id_num ? id_num[12..13] : id_num
        # 判断复姓
        # 重置姓名，因为后面有 next 跳出 data.each 循环，所以不能在末尾重置
        firstname = ''
        lastname = ''
        if !fullname
          errorProfiles << [fullname, id_num, cellphone, '缺少姓名']
          next
        else
          COMPOUND_NAME.each do |fname|
            if fullname.include? fname
              firstname = fname
              lastname  = fullname.gsub(fname,'')
              break
            end # if fullname
          end # COMPOUND_NAME
        end # if !=fullname

        # 数据验证
        if !id_num
          errorProfiles << [fullname, id_num, cellphone, '缺少身份证']
        elsif !cellphone
          errorProfiles << [fullname, id_num, cellphone, '缺少手机号']
        elsif id_num.length != 18
          errorProfiles << [fullname, id_num, cellphone, '身份证位数不对']
        elsif !(id_num =~ /(x|X|\d)$/)
          errorProfiles << [fullname, id_num, cellphone, '身份证末位有误']
        elsif cellphone.length != 11 
          errorProfiles << [fullname, id_num, cellphone, '手机号位数不对']
        elsif 2017 - year.to_i > 60
          errorProfiles << [fullname, id_num, cellphone, '年龄大于60岁']
        elsif Profile.find_by_cellphone(cellphone)
          errorProfiles << [fullname, id_num, cellphone, '数据库：手机号重复']
        elsif Profile.find_by_id_num(id_num)
          errorProfiles << [fullname, id_num, cellphone, '数据库：身份证重复']
        else
          begin 
            birthday.to_date
          rescue
            errorProfiles << [fullname, id_num, cellphone, '生日有误']
            next
          end
          # 姓名识别（已经判断过复姓）
          firstname = firstname != '' ? firstname : fullname[0]
          lastname = lastname != '' ? lastname : fullname[1..-1]
          if is_store
            Profile.create(
              firstname: firstname,
              lastname: lastname,
              gender: id_num[-2].to_i.even? ? '女' : '男',
              birthday: year + '-' + month + '-' + day,
              id_num: id_num,
              email: email,
              cellphone: cellphone,
              employer: employer,
              occupation: occupation,
              position: position,
              province: province ? province : '四川省',
              city: city ? city : '成都市',
              address: address,
              zipcode: zipcode
              )
          end
          correctProfiles << [
            firstname,
            lastname,
            id_num,
            cellphone,
            '导入成功'
            # 生成全数据，暂时感觉没必要，以后有需求再开启
            # id_num[-2].to_i.even? ? '女' : '男',
            # year + '-' + month + '-' + day,
            # id_num,
            # email,
            # cellphone,
            # employer,
            # occupation,
            # position,
            # province=='' ? '四川省' : province,
            # city=='' ? '成都市' : city,
            # address,
            # zipcode
          ]
        end # if validation
      end # data.each

      # 结果输出 csv
      CSV.open('/app/import_results/import_results_' + file_name + '.csv', "wb") do |csv|
        csv << %W[姓名 身份证 电话]
        correctProfiles.each do |pf|
          csv << pf
        end
        csv << ['华丽' '丽的' '分割' '线']
        errorProfiles.each do |pf|
          csv << pf
        end
      end # CSV.open
    end # def

    def start_to_send(start_num)
      Profile.find_each(start: start_num) do |pf|
      # Profile.find_each(batch_size: 100, start: 5936, finish: 5918) do |pf|
        # pf = Profile.find(start_num);
        ['PC0000000139', 'PC0000000151', 'PC0000000150', 'PC0000000167'].each do |present_code|
          response = Profile.send_to_metlife(pf, present_code)
          case present_code
          when 'PC0000000139'
            pf.update(PC139: pf.check_response(response.to_s))
            pf.save
          when 'PC0000000151'
            pf.update(PC151: pf.check_response(response.to_s))
            pf.save
          when 'PC0000000150'
            pf.update(PC150: pf.check_response(response.to_s))
            pf.save
          when 'PC0000000167'
            pf.update(PC167: pf.check_response(response.to_s))
            pf.save
          end # case
        end # ['present_code']
      end # Profile.find_each
    end # def

    # Build xml file.
    def build_xml_of_free_insurance(profile, present_code)
      data = ''
      xml = ::Builder::XmlMarkup.new(target: data, indent: 0)
      # xml.instruct!
      xml.instruct! :xml, version: "1.0", encoding: "GBK"
      xml.Records {
        xml.Record {
          xml.Customer {
            xml.Key Profile.generate_free_insurance_id
            xml.ChannelType 'aishanxing'
            xml.FromSystem 'AiShanXing'
            xml.Name profile.full_name
            xml.Sex profile.gender ? 'Male' : 'Female'
            xml.Birthday profile.birthday.to_s
            xml.Document profile.id_num
            xml.DocumentType 'IdentityCard'
            xml.Email profile.email
            xml.Mobile profile.cellphone
            xml.ContactState {
              xml.Name profile.province
            }
            xml.ContactCity {
              xml.Name profile.city
            }
            xml.ContactAddress profile.address
            xml.Occupation {
              xml.Code '0001001'
            }
            # 没有description
            xml.Description
          }
          xml.Task {
            xml.CallList {
              xml.Name ''
            }
            xml.Campaign {
              xml.Name ''
            }
          }
          xml.Activity {
            xml.Code ''
            xml.Present {
              xml.Code present_code
            }
            xml.TSR {
              xml.Code '805095'
            }
            xml.DonateTime Date.current.to_s(:db)
            xml.SMS '1'
            xml.FlightNo
            xml.ValidTime
          }
        }
      }

      return data
    end

    # Send the xml via SOAP
    def send_to_metlife(profile, present_code)
      # pc = Array['PC0000000139', 'PC0000000151', 'PC0000000150', 'PC0000000167']
      # Connect to MetLife SOAP API via wsdl.
      client = Savon.client(wsdl: "http://icare.metlife.com.cn/services/YSW2ICareSave?wsdl", encoding: "GBK")
     
      msg = Profile.build_xml_of_free_insurance(profile, present_code)

      # Debug the API performance.
      puts 'XXXXXXXXXXXXXXXXXX'
      puts msg
      puts 'XXXXXXXXXXXXXXXXXX'

      # response = Hash.new
      
      # msg.each do |key, message|
      #   response[key] = client.call(:do_request, message: { xml_input: message })
      # end

      response = client.call(:do_request, message: { xml_input: msg })

      # Debug the API performance.
      puts '-----------------------'
      puts response
      puts '-----------------------'

      return response
    end

    # def response_from_metlife(response)
    #   if response.nil?
    #     return nil
    #   else
    #     result = Hash.new
    #     response.each do |key, response|
    #       response_body = Nokogiri::XML(response.hash[:envelope][:body][:do_request_response][:do_request_return])
    #       result[key] = [response_body.xpath("//FreeInsureNo").text]
    #     end
    #   end

    #   return result
    # end

    def generate_free_insurance_id
      return 'AiShanXing' + DateTime.current.in_time_zone('Beijing').to_s(:number) + ('0'..'9').to_a.shuffle[0..3].join
    end

    def to_csv file_name, start_num
      CSV.open('/app/import_results/' + file_name + '.csv', "wb") do |csv|
        csv << FILE_HEADER
        Profile.find_each(start: start_num) do |pf|
          csv << pf.profile_row_info
        end
      end
    end

    def convert_wrong_unicode_to_chinese(start_num)
      Profile.find_each(start: start_num) do |pf|
        ['PC139', 'PC151', 'PC150', 'PC167'].each do |code|
          if pf.send("#{code}").include?('&#x5DF2;&#x6709;&#x8D60;&#x9669;&#x8BB0;&#x5F55;')
            pf.update("#{code}": '客户已有赠险记录,无法导入!!')
          elsif pf.send("#{code}").include?('&#x5C0F;&#x4E8E;18&#x4F4D;')
            pf.update("#{code}": '身份证号长度不能小于18位!!')
          end
        end
        pf.save
      end
    end

  end
end
