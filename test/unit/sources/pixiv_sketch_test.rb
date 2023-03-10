require 'test_helper'

module Sources
  class PixivSketchTest < ActiveSupport::TestCase
    context "A Pixiv Sketch post" do
      strategy_should_work(
        "https://sketch.pixiv.net/items/5835314698645024323",
        image_urls: ["https://img-sketch.pixiv.net/uploads/medium/file/9986983/8431631593768139653.jpg"],
        page_url: "https://sketch.pixiv.net/items/5835314698645024323",
        profile_urls: ["https://sketch.pixiv.net/@user_ejkv8372", "https://www.pixiv.net/users/44772126"],
        profile_url: "https://sketch.pixiv.net/@user_ejkv8372",
        artist_name: "user_ejkv8372",
        other_names: ["user_ejkv8372", "γ΅γ³"],
        artist_commentary_desc: "π»γ·γ£γ³γ―γΉγ¨γγγΌγ―θͺηζ₯γγγ§γ¨γπ»οΌιε»η΅΅οΌ ",
        tags: []
      )
    end

    context "A Pixiv Sketch image with referer" do
      strategy_should_work(
        "https://img-sketch.pixiv.net/uploads/medium/file/9986983/8431631593768139653.jpg",
        referer: "https://sketch.pixiv.net/items/5835314698645024323",
        image_urls: ["https://img-sketch.pixiv.net/uploads/medium/file/9986983/8431631593768139653.jpg"],
        page_url: "https://sketch.pixiv.net/items/5835314698645024323",
        profile_urls: ["https://sketch.pixiv.net/@user_ejkv8372", "https://www.pixiv.net/users/44772126"],
        profile_url: "https://sketch.pixiv.net/@user_ejkv8372",
        artist_name: "user_ejkv8372",
        other_names: ["user_ejkv8372", "γ΅γ³"],
        artist_commentary_desc: "π»γ·γ£γ³γ―γΉγ¨γγγΌγ―θͺηζ₯γγγ§γ¨γπ»οΌιε»η΅΅οΌ ",
        tags: []
      )
    end

    context "A Pixiv Sketch image without the referer" do
      # page: https://sketch.pixiv.net/items/8052785510155853613
      strategy_should_work(
        "https://img-sketch.pixiv.net/uploads/medium/file/9988973/7216948861306830496.jpg",
        page_url: nil,
        profile_url: nil,
        artist_name: nil,
        tags: [],
        artist_commentary_desc: nil
      )
    end

    context "A NSFW post" do
      strategy_should_work(
        "https://sketch.pixiv.net/items/193462611994864256",
        image_urls: ["https://img-sketch.pixiv.net/uploads/medium/file/884876/4909517173982299587.jpg"],
        page_url: "https://sketch.pixiv.net/items/193462611994864256",
        profile_url: "https://sketch.pixiv.net/@lithla",
        artist_name: "lithla",
        other_names: ["lithla", "γͺγͺγΉγ©γ¦γ"],
        artist_commentary_desc: "γγγγ³ι²εΊγγ¬γ€ γγΌγΉ",
        tags: []
      )
    end

    context "A post with multiple images" do
      desc = <<~EOS.normalize_whitespace
        3ζ3ζ₯γ―γγγγγ?ζ₯γγγγγ?γ§


        βΌεΆδ½ιη¨
        βεΆδ½ιη¨
        β οΎοΎο½ΊοΎοΎ(ο½±οΎοΎ)
        β‘οΎοΎο½ΊοΎοΎ(οΎοΎοΎοΎ)
        β’ο½ΊοΎοΎ(οΎοΎο½ΈοΎοΎοΎοΎ)+θ²ο½±οΎοΎ
        β£1ε(οΎοΎε)
        β€1ε(οΎοΎε)(η·γ?γΏ)
        β₯θ²οΎοΎ
        β¦δ»δΈγβε?ζ
        β¨ε?ζ(ο½ΎοΎοΎο½±οΎοΎοΎο½°οΎ)
        β§ε?ζ(ο½ΈοΎοΎο½°οΎοΎο½ΈοΎ)

        θ²γΎγ§γ€γγζιγ¨εΏγ?δ½θ£γη‘γγ?γ§γ’γγ―γ­γ§γγγγ
        γγγ§γ5ζιγγγγγγ£γ¦γ(β’ο½β£γ?ιγ§30εγγγιε)

        γγ£γ±οΎοΎγγοΌεγ―ζιγγγβ¦
        γ»η·η»γ γγγη«δ½γζζ‘γ§γγͺγ(ι ­γ?δΈ­γ§3Dεγ§γγͺγ)
        γ»ζγηΆγγ¦γγ¨η«δ½ζγγ²γ·γ₯γΏγ«γε΄©ε£γγ
        γ»η?γ?γγ³γγεγγͺγ
        γ?γ§1ο½2εδΌζ©γγ¦η?γ¨ι ­δΌγΎγγͺγγ¨γγγͺγγ?γγγ€γ
        η?γ¨ι ­γ?γΉγΏγγδΈθΆ³γ―ε¦δ½γ¨γγγγγ

        η·η»γ?γΏγγζθ¦ηγ«η«δ½ζζ‘γ§γγγη’Ίγγη?γγΏγγγͺζζ³γη·΄γγγεΏθ¦γγγβ¦γ?γ―γγγ£γ¦γγγ©
        γζ­ι’ε³γ
        γιζγͺζΏγθ¨­ε?γγ¦ε₯₯θ‘γγγΌγΉη’Ίθͺγ
        γε°ι’γ«ζ­£ζΉε½’γζγγ¦ηΈ¦γγΌγΉη’Ίθͺγ
        γι’η―ι¨γθ΄δ½δΈ­ε€?ι¨γ«ζ Έ(δΈΈ)γζγγ¦η«δ½η’Ίθͺγ
        γη·η»γγζ·‘γθ‘¨η€ΊγδΈγγη°‘εγͺη«δ½γ’γγ«γζγγ¦γΏγ¦γε€§γγζ―ηγ?η’Ίθͺγ
        β¦γγγγγͺζγγ€γγ?γ―

        γγ¨εζγ«θΆ³ι¦γ?ι’η―η΄ δ½ζγγ¦η«δ½ζζ‘γγ¦γθ·‘γγγ
        γγΎγ γ«ι’η―γ?θ»ΈγθΆ³ι¦γ?γγ³γ«θ¨­ε?γγγ°θͺηΆγ«θ¦γγγθΏ·γ
        ε€εζε€§γ«δΌΈγ°γγγζ²γγγγγ¦γγ¨γγ―ι’η―ζ΅?γγ¦γγγγγγ γγγγη°‘εγͺθ»Έθ¨­ε?γ γ¨ιεζγεΊγ¦γγγγ γ¨γ―ζγ

        #εΆδ½ιη¨
        #γγ?γγ°
        #γγ?η΄ ζ΄γγγδΈηγ«η₯η¦γοΌ
        #γ»γ
        #γγγΌ
        #3ζ3ζ₯
        #ε·¨δΉ³
        #ι»ι«ͺε·¨δΉ³
        #γΏγ€γ
      EOS

      strategy_should_work(
        "https://sketch.pixiv.net/items/8052785510155853613",
        image_urls: %w[
          https://img-sketch.pixiv.net/uploads/medium/file/9988964/1564052114639195387.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988965/3187185972065199018.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988966/5281789458380074490.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988967/8187710652175488805.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988968/3497441770651131427.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988969/1770110164450415039.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988970/1340350233137289970.png
          https://img-sketch.pixiv.net/uploads/medium/file/9988971/9105451079763734305.jpg
          https://img-sketch.pixiv.net/uploads/medium/file/9988972/2641925439408057307.jpg
          https://img-sketch.pixiv.net/uploads/medium/file/9988973/7216948861306830496.jpg
        ],
        artist_commentary_desc: desc,
        artist_name: "op-one",
        page_url: "https://sketch.pixiv.net/items/8052785510155853613",
        profile_url: "https://sketch.pixiv.net/@op-one",
        tags: %w[εΆδ½ιη¨ γγ?γγ° γγ?η΄ ζ΄γγγδΈηγ«η₯η¦γ γ»γ γγγΌ 3ζ3ζ₯ ε·¨δΉ³ ι»ι«ͺε·¨δΉ³ γΏγ€γ]
      )
    end

    should "Parse Pixiv Sketch URLs correctly" do
      assert(Source::URL.image_url?("https://img-sketch.pixiv.net/uploads/medium/file/4463372/8906921629213362989.jpg "))
      assert(Source::URL.image_url?("https://img-sketch.pximg.net/c!/w=540,f=webp:jpeg/uploads/medium/file/4463372/8906921629213362989.jpg"))
      assert(Source::URL.image_url?("https://img-sketch.pixiv.net/c/f_540/uploads/medium/file/9986983/8431631593768139653.jpg"))
      assert(Source::URL.page_url?("https://sketch.pixiv.net/items/5835314698645024323"))
      assert(Source::URL.profile_url?("https://sketch.pixiv.net/@user_ejkv8372"))
    end
  end
end
